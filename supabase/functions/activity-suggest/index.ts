// 周辺のアクティビティ提案(お金のかからない地域の催し)を、Gemini API で
// 生成する Edge Function。
//
// 検索グラウンディング(Google検索)は使わない: 2026-09-09の実測で、このプロジェクトの
// キーでは google_search ツールを付けると無料枠が無く429を即返すと確認した
// (response_format のみなら200)。追加課金を避けるため、実在の場所候補は
// Overpass API(OpenStreetMap。APIキー不要・無料・利用登録不要)から取得し、
// Gemini にはその候補の中から選んで遊び方を書かせるだけにする。これにより
// place_name / 緯度経度は実在データになり、Geminiが施設名を捏造するリスクを
// 構造的に排除できる(下記 fetchNearbyPlaces / callGemini 参照)。
//
// クライアント(Flutter)は anon キー(呼び出し元のJWT付き)でこの関数を呼ぶ。
// activity_suggestions への書き込みは service role の責務なので(db_schema.md 参照)、
// 生成・永続化はすべてここで行う。
//
// リクエストボディ:
//   { child_id: string, latitude: number, longitude: number, force?: boolean }
//
// 必要な環境変数(secrets):
//   GEMINI_API_KEY (必須。ai-review と共有)
//   GEMINI_MODEL   (任意。既定 gemini-3.6-flash。ai-review と共有。
//                   この既定値は ai-review/index.ts にもハードコードされている
//                   ため、変更するときは両方のファイルを直すこと)
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY は
// Edge Function に自動注入される。
//
// gemini-3.8-flash は使わないこと。実測(2026-09-09)で、このプロジェクトのキーでは
// 同モデルだけが応答を返さず45秒でタイムアウトした。3.7-flash / 3.6-flash /
// 3.5-flash-lite はいずれも数秒で 200 を返す。

import { createClient } from "npm:@supabase/supabase-js@2";

const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.6-flash";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");

const MAX_ITEMS = 5;
const CACHE_TTL_HOURS = 6;
const CACHE_RADIUS_DEG = 0.02; // 約2km。少し移動しただけでは再生成しない
const RATE_LIMIT_WINDOW_HOURS = 24;
const RATE_LIMIT_MAX_GENERATIONS = MAX_ITEMS * 4; // 1日4回の生成まで

interface RequestBody {
  child_id: string;
  latitude: number;
  longitude: number;
  force?: boolean;
}

interface GeminiActivity {
  title: string;
  description: string;
  place_name: string;
  is_free: boolean;
  // Overpass候補との突き合わせで得られた実在座標。候補が無い/一致しなかった
  // 場合は null(callGemini内でその活動自体を捨てるのは候補ありのときだけ。
  // 候補なしフォールバック時は null のまま許可する。下記callGemini参照)。
  latitude: number | null;
  longitude: number | null;
}

// Overpass API (OpenStreetMap) から取得した実在の候補地。
interface PlaceCandidate {
  name: string;
  category: string; // プロンプトに出す日本語ラベル(例: "図書館")
  latitude: number;
  longitude: number;
  distanceM: number;
}

// Gemini 側の無料枠クォータ超過 (429)。自前のレートリミット (下の
// RATE_LIMIT_MAX_GENERATIONS) も 429 を返すため、クライアントは HTTP ステータス
// だけでなく body の `error` 値 ("gemini_quota_exceeded" か "rate_limited" か) で
// 区別する必要がある。
class GeminiQuotaExceededError extends Error {}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// 「無料で行きやすい」に対応するOSMタグだけを対象にする(図書館・公民館・児童館・
// 公園・遊び場・運動広場)。美術館・スポーツセンターなど有料の可能性が高い種別は
// 誤って無料と案内するリスクがあるため含めない。
const OVERPASS_CATEGORIES: { query: string; category: string }[] = [
  { query: 'node["amenity"="library"]', category: "図書館" },
  { query: 'node["amenity"="community_centre"]', category: "公民館・児童館" },
  { query: 'node["leisure"="park"]', category: "公園" },
  { query: 'way["leisure"="park"]', category: "公園" },
  { query: 'node["leisure"="playground"]', category: "遊び場" },
  { query: 'node["leisure"="pitch"]', category: "運動広場" },
];
const OVERPASS_RADIUS_M = 2000;
const MAX_CANDIDATES = 12;

function haversineMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Overpass API(OpenStreetMapの無料クエリサービス。APIキー・登録不要)から、
// 現在地の半径2km以内にある実在の公共施設候補を取得する。
// 失敗・タイムアウト・0件はいずれも例外にせず空配列を返す(呼び出し側で
// 「候補なし」の一般的なプロンプトにフォールバックするため)。
async function fetchNearbyPlaces(lat: number, lon: number): Promise<PlaceCandidate[]> {
  const filters = OVERPASS_CATEGORIES
    .map((c) => `${c.query}(around:${OVERPASS_RADIUS_M},${lat},${lon});`)
    .join("\n  ");
  const query = `[out:json][timeout:10];\n(\n  ${filters}\n);\nout center 60;`;

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 8000);
  try {
    const res = await fetch("https://overpass-api.de/api/interpreter", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `data=${encodeURIComponent(query)}`,
      signal: controller.signal,
    });
    if (!res.ok) {
      console.error("Overpass API returned", res.status, await res.text());
      return [];
    }
    const data = await res.json();
    const elements = Array.isArray(data.elements) ? data.elements : [];

    const byName = new Map<string, PlaceCandidate>();
    for (const el of elements) {
      const name: string | undefined = el.tags?.name;
      if (!name) continue; // 名前不明な施設はGeminiに渡しても使えないので除外
      const elLat = el.type === "node" ? el.lat : el.center?.lat;
      const elLon = el.type === "node" ? el.lon : el.center?.lon;
      if (typeof elLat !== "number" || typeof elLon !== "number") continue;

      const distanceM = haversineMeters(lat, lon, elLat, elLon);
      const existing = byName.get(name);
      if (existing && existing.distanceM <= distanceM) continue; // 同名は近い方を残す

      const tagKey = el.tags?.amenity === "library"
        ? "図書館"
        : el.tags?.amenity === "community_centre"
        ? "公民館・児童館"
        : el.tags?.leisure === "park"
        ? "公園"
        : el.tags?.leisure === "playground"
        ? "遊び場"
        : el.tags?.leisure === "pitch"
        ? "運動広場"
        : "施設";

      byName.set(name, { name, category: tagKey, latitude: elLat, longitude: elLon, distanceM });
    }

    return [...byName.values()]
      .sort((a, b) => a.distanceM - b.distanceM)
      .slice(0, MAX_CANDIDATES);
  } catch (err) {
    console.error("Overpass API call failed", err);
    return [];
  } finally {
    clearTimeout(timeoutId);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const { child_id, latitude, longitude, force } = body ?? {};
  if (!child_id || typeof latitude !== "number" || typeof longitude !== "number") {
    return jsonResponse({ error: "missing_fields" }, 400);
  }
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return jsonResponse({ error: "invalid_location" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // 呼び出し元の JWT で anon クライアントを作る。profiles_select_group RLS
  // (同一グループの全員がプロフィールを見られる)により、対象の子の行が
  // 取れれば「呼び出し元は同じグループのメンバー」であることが保証される。
  // 親・子どちらから呼んでも同じ検証で通る。
  // display_name は取らない(子どもの名前を外部APIに送らないため)。
  const authHeader = req.headers.get("Authorization") ?? "";
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: childProfile, error: childErr } = await callerClient
    .from("profiles")
    .select("id, group_id")
    .eq("id", child_id)
    .maybeSingle();

  if (childErr) {
    return jsonResponse({ error: "auth_check_failed", detail: childErr.message }, 500);
  }
  if (!childProfile) {
    return jsonResponse({ error: "forbidden" }, 403);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);

  if (!force) {
    const since = new Date(Date.now() - CACHE_TTL_HOURS * 3600_000).toISOString();
    const { data: cached } = await admin
      .from("activity_suggestions")
      .select("id, title, description, place_name, latitude, longitude, source_url, created_at")
      .eq("child_id", child_id)
      .gte("created_at", since)
      .gte("origin_latitude", latitude - CACHE_RADIUS_DEG)
      .lte("origin_latitude", latitude + CACHE_RADIUS_DEG)
      .gte("origin_longitude", longitude - CACHE_RADIUS_DEG)
      .lte("origin_longitude", longitude + CACHE_RADIUS_DEG)
      .order("created_at", { ascending: false })
      .limit(MAX_ITEMS);

    if (cached && cached.length > 0) {
      return jsonResponse({ suggestions: cached, model: GEMINI_MODEL, cached: true });
    }
  }

  // 連打対策: 直近24時間の生成件数が上限を超えたら実際の生成を拒否する。
  const dayAgo = new Date(Date.now() - RATE_LIMIT_WINDOW_HOURS * 3600_000).toISOString();
  const { count } = await admin
    .from("activity_suggestions")
    .select("id", { count: "exact", head: true })
    .eq("child_id", child_id)
    .gte("created_at", dayAgo);
  if ((count ?? 0) >= RATE_LIMIT_MAX_GENERATIONS) {
    return jsonResponse({ error: "rate_limited" }, 429);
  }

  if (!GEMINI_API_KEY) {
    return jsonResponse({ error: "gemini_not_configured" });
  }

  const candidates = await fetchNearbyPlaces(latitude, longitude);

  let activities: GeminiActivity[];
  try {
    activities = await callGemini({ latitude, longitude, candidates });
  } catch (err) {
    console.error("Gemini call failed", err);
    if (err instanceof GeminiQuotaExceededError) {
      return jsonResponse({ error: "gemini_quota_exceeded" }, 429);
    }
    return jsonResponse({ error: "gemini_call_failed", detail: `${err}` }, 502);
  }

  // サーバ側フィルタ: プロンプトだけに頼らず、無料でないもの・タイトルが空の
  // ものは機械的に捨て、MAX_ITEMS に切り詰める。
  // 「おうちの人と確認」の一文も、プロンプト遵守だけに頼らずここで機械的に保証する。
  const CONFIRM_SUFFIX = "場所や開いている時間は、おでかけの前におうちの人と確認してください。";
  const filtered = activities
    .filter((a) => a.is_free === true && a.title.trim().length > 0)
    .slice(0, MAX_ITEMS)
    .map((a) => ({
      ...a,
      description: a.description.includes("確認")
        ? a.description
        : `${a.description} ${CONFIRM_SUFFIX}`.trim(),
    }));

  if (filtered.length === 0) {
    return jsonResponse({ suggestions: [], model: GEMINI_MODEL, cached: false });
  }

  const rows = filtered.map((a) => ({
    group_id: childProfile.group_id,
    child_id,
    title: a.title,
    description: a.description || null,
    place_name: a.place_name || null,
    // Overpass(OpenStreetMap)候補と一致した場合のみ実在の座標が入る。検索
    // グラウンディングは使わないため出典URLは常に取得できず null のまま。
    latitude: a.latitude,
    longitude: a.longitude,
    source_url: null,
    origin_latitude: latitude,
    origin_longitude: longitude,
  }));

  const { data: inserted, error: insertErr } = await admin
    .from("activity_suggestions")
    .insert(rows)
    .select("id, title, description, place_name, latitude, longitude, source_url, created_at");

  if (insertErr) {
    console.error("activity_suggestions insert failed", insertErr);
    return jsonResponse({ error: "save_failed", detail: insertErr.message }, 500);
  }

  return jsonResponse({ suggestions: inserted, model: GEMINI_MODEL, cached: false });
});

async function callGemini(
  input: { latitude: number; longitude: number; candidates: PlaceCandidate[] },
): Promise<GeminiActivity[]> {
  const hasCandidates = input.candidates.length > 0;

  const systemInstruction = [
    "あなたは、日本の小中学生とその保護者に向けて、お金をかけずに参加できる地域の過ごし方を提案する地域情報アドバイザーです。",
    "目的は、子どもがSNSや動画から離れて現実の時間を有意義に使えるよう、実行しやすい選択肢を示すことです。",
    "【最優先の制約】参加費が無料のもの、または子どもは無料のものだけを提案してください。有料の施設・イベント・交通費が大きくかかるものは提案しないでください。",
    "【安全性】子どもだけ、または保護者と一緒に安全に参加できるものに限定します。",
    "次のものは絶対に含めないでください: 夜間のみの催し、飲酒を伴う場、個人宅や不特定多数の私的な募集、出会い目的の集まり、宗教・政治への勧誘、危険を伴う活動、年齢制限のある場所。",
    hasCandidates
      ? "【誠実さ】あなたはWeb検索を行えません。place_name には、ユーザーメッセージで渡す「候補地リスト」に載っている名称と完全に一致する文字列だけを使ってください。リストに無い施設名・場所名を作ってはいけません。"
      : "【誠実さ】あなたはWeb検索を行えません。自分の知識だけで答えるため、施設名やイベント名を推測で作ってはいけません。place_name は固有名詞に確信が持てない場合は推測で書かず、「お近くの市立図書館」「近くの児童公園」のように種類がわかる一般的な書き方にしてください。",
    "期間限定のイベント・お祭り・ワークショップ・開催日が決まっている催しは提案しないでください。一年を通していつでも行ける場所だけを挙げてください。",
    "具体的な開催日時・料金・電話番号・URL・アクセス方法は書かないでください。誤った情報を子どもに渡さないためです。",
    "description は丁寧語で書き、最後に必ず『場所や開いている時間は、おでかけの前におうちの人と確認してください。』を添えてください。",
    "出力はすべて日本語で、小学校高学年が読める平易な言葉にし、指定されたJSONスキーマの形式でのみ返してください。",
  ].join("\n");

  const candidateListText = hasCandidates
    ? input.candidates
      .map((c, i) => `${i + 1}. ${c.name}(${c.category}、現在地から約${Math.round(c.distanceM)}m)`)
      .join("\n")
    : null;

  const prompt = [
    `子どもの現在地: 緯度 ${input.latitude.toFixed(4)}, 経度 ${input.longitude.toFixed(4)}`,
    `今日の日付: ${new Date().toISOString().slice(0, 10)}`,
    "",
    ...(candidateListText
      ? [
        "現在地の近くにある実在の候補地リスト(この中からだけ選ぶこと):",
        candidateListText,
        "",
        "上記の候補地の中から、活動内容に合いそうなものを選んで(全部使わなくてよい)、",
        "お金のかからない過ごし方を最大5件、JSONで提案してください。",
      ]
      : [
        "この場所から徒歩・自転車・公共交通で30分以内で行ける範囲で、",
        "お金のかからない過ごし方を5件、JSONで提案してください。",
      ]),
    "",
    "各要素に必要な情報:",
    "- title: アクティビティ名。子どもが読んでワクワクする短い見出し(20文字程度)。場所名ではなく、",
    "  やってみたくなる遊び方の見出しにしてください(例:「図書館で世界の絵本さがし」)",
    "- description: 詳細情報。何ができるか / どんな人向けか / 持ち物や注意点 を2〜3文で。最後に確認を促す一文",
    hasCandidates
      ? "- place_name: 上で渡した候補地リストの名称と完全に一致する文字列(自分で作らない)"
      : "- place_name: 施設名や場所の名前",
    "- is_free: 完全に無料なら true。少しでも費用がかかるなら false",
    "",
    "同じ施設ばかりにならないよう、屋内・屋外・体を動かすもの・学べるもの をバランスよく混ぜてください。",
    "実在しない場所を作らないことが最優先です。5件に届かなくてもかまいません。確実に知っている場所だけを挙げてください。",
    ...(hasCandidates ? [] : [
      "かわりに、一年中いつでも無料で行ける場所(公園・図書館・公民館・児童館・市民センター・河川敷や遊歩道・無料の運動広場など)を挙げ、",
      "「そこで何ができるか」「どんな楽しみ方があるか」を具体的に書いてください。場所そのものは一般的でも、子どもがやってみたくなる提案にしてください。",
    ]),
  ].join("\n");

  const res = await fetch("https://generativelanguage.googleapis.com/v1beta/interactions", {
    method: "POST",
    headers: {
      "x-goog-api-key": GEMINI_API_KEY!,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: GEMINI_MODEL,
      system_instruction: systemInstruction,
      input: prompt,
      response_format: {
        type: "text",
        mime_type: "application/json",
        schema: {
          type: "object",
          properties: {
            activities: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  title: { type: "string" },
                  description: { type: "string" },
                  place_name: { type: "string" },
                  is_free: { type: "boolean" },
                },
                required: ["title", "description", "place_name", "is_free"],
              },
            },
          },
          required: ["activities"],
        },
      },
      // この経路は検索グラウンディングを使わないため一度も成功実績がなく、2000では
      // 実証が無い。日本語5件分(見出し+2〜3文+締め文)に加え、Gemini 3系は思考トークンも
      // この枠から消費するため、切り詰められて JSON.parse が失敗するのを避けるために
      // 余裕を持たせている。
      generation_config: { max_output_tokens: 4000 },
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    if (res.status === 429) {
      throw new GeminiQuotaExceededError(`Gemini API returned 429: ${text}`);
    }
    throw new Error(`Gemini API returned ${res.status}: ${text}`);
  }

  const data = await res.json();

  // Interactions API のレスポンスは steps[] (outputs ではない)。
  // type === "model_output" の content から type === "text" の text を連結する。
  const texts: string[] = [];
  for (const step of data.steps ?? []) {
    if (step.type !== "model_output") continue;
    for (const block of step.content ?? []) {
      if (block.type === "text" && typeof block.text === "string") {
        texts.push(block.text);
      }
    }
  }

  const joined = texts.join("");
  if (!joined) {
    throw new Error(`Gemini API response had no text content: ${JSON.stringify(data)}`);
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(joined);
  } catch {
    throw new Error(`Failed to parse Gemini JSON output: ${joined}`);
  }

  const obj = parsed as Record<string, unknown>;
  const rawActivities = Array.isArray(obj.activities) ? obj.activities : [];

  // 候補地リストを渡した場合は、name の完全一致でしか実在座標を割り当てない。
  // 一致しない place_name は「リストにない名前を作った」ことを意味するため、
  // プロンプト指示だけに頼らずここで機械的に弾く(誠実性の最終防波堤)。
  const candidateByName = new Map(input.candidates.map((c) => [c.name, c]));

  const activities: GeminiActivity[] = [];
  for (const a of rawActivities) {
    const item = a as Record<string, unknown>;
    const placeName = String(item.place_name ?? "");
    const match = candidateByName.get(placeName);

    if (hasCandidates && !match) continue; // 捏造された地名は破棄する

    activities.push({
      title: String(item.title ?? ""),
      description: String(item.description ?? ""),
      place_name: placeName,
      is_free: item.is_free === true,
      latitude: match?.latitude ?? null,
      longitude: match?.longitude ?? null,
    });
  }

  // 0件はエラーではない: プロンプトで「実在しない場所を作らないことが最優先。
  // 5件に届かなくてもかまわない」と明示的に指示しているため、モデルが正当に
  // 空配列を返すことがある(候補地との不一致で全件破棄された場合も含む)。
  // 呼び出し側の filtered.length === 0 分岐が { suggestions: [] } を返す想定
  // であり、ここで例外にすると502に化けてしまう。
  return activities;
}
