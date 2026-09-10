// AI講評 (summary + advice + dopagaki_score) を Gemini API で生成する Edge Function。
//
// クライアント(Flutter)は anon キー(呼び出し元のJWT付き)でこの関数を呼ぶ。
// ai_reviews への書き込みは service role の責務なので(db_schema.md 参照)、
// 生成・永続化はすべてここで行う。
//
// リクエストボディ:
//   { child_id: string, date: string (YYYY-MM-DD),
//     screen_time: { total_minutes: number,
//                    apps: { name: string, minutes: number, app_id?: string }[] },
//     force?: boolean }
//
// どのアプリが「ドパガキ対象」(SNS・動画・ゲーム)かはクライアントでは判定せず、
// アプリ名とパッケージ名から Gemini に判定させる。対象アプリは次々に増えるため、
// アプリ側の固定カタログでは追いつかないという判断。
//
// 必要な環境変数(secrets):
//   GEMINI_API_KEY (必須)
//   GEMINI_MODEL   (任意。既定 gemini-3.6-flash。この既定値は
//                   activity-suggest/index.ts にもハードコードされている
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

interface AppUsageInput {
  name: string;
  minutes: number;
  /** Android のパッケージ名。表示名だけでは何のアプリか判別できない場合の手がかり。 */
  app_id?: string;
}

interface RequestBody {
  child_id: string;
  date: string;
  screen_time: {
    total_minutes: number;
    apps: AppUsageInput[];
  };
  force?: boolean;
}

interface GeminiResult {
  dopagaki_score: number;
  score_reason: string;
  summary: string;
  advice: string[];
}

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

  const { child_id, date, screen_time, force } = body ?? {};
  if (!child_id || !date || !screen_time) {
    return jsonResponse({ error: "missing_fields" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // 呼び出し元の JWT で anon クライアントを作る。profiles_select_group RLS
  // (同一グループの全員がプロフィールを見られる)により、対象の子の行が
  // 取れれば「呼び出し元は同じグループのメンバー」であることが保証される。
  // 親・子どちらから呼んでも同じ検証で通る。
  const authHeader = req.headers.get("Authorization") ?? "";
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: childProfile, error: childErr } = await callerClient
    .from("profiles")
    .select("id, display_name")
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
    const { data: existing } = await admin
      .from("ai_reviews")
      .select("dopagaki_score, score_reason, comment, advice, model, created_at")
      .eq("child_id", child_id)
      .eq("date", date)
      .maybeSingle();

    if (existing) {
      return jsonResponse({
        dopagaki_score: existing.dopagaki_score,
        score_reason: existing.score_reason,
        summary: existing.comment,
        advice: existing.advice ?? [],
        model: existing.model,
        created_at: existing.created_at,
        cached: true,
      });
    }
  }

  if (!GEMINI_API_KEY) {
    return jsonResponse({ error: "gemini_not_configured" });
  }

  let result: GeminiResult;
  try {
    result = await callGemini({
      childName: childProfile.display_name as string,
      date,
      totalMinutes: screen_time.total_minutes,
      apps: screen_time.apps ?? [],
    });
  } catch (err) {
    console.error("Gemini call failed", err);
    return jsonResponse({ error: "gemini_call_failed", detail: `${err}` }, 502);
  }

  const clampedScore = Math.max(0, Math.min(100, Math.round(result.dopagaki_score)));

  const { error: upsertErr } = await admin.from("ai_reviews").upsert(
    {
      child_id,
      date,
      dopagaki_score: clampedScore,
      score_reason: result.score_reason,
      comment: result.summary,
      advice: result.advice,
      model: GEMINI_MODEL,
    },
    { onConflict: "child_id,date" },
  );

  if (upsertErr) {
    console.error("ai_reviews upsert failed", upsertErr);
    return jsonResponse({ error: "save_failed", detail: upsertErr.message }, 500);
  }

  return jsonResponse({
    dopagaki_score: clampedScore,
    score_reason: result.score_reason,
    summary: result.summary,
    advice: result.advice,
    model: GEMINI_MODEL,
    created_at: new Date().toISOString(),
    cached: false,
  });
});

async function callGemini(input: {
  childName: string;
  date: string;
  totalMinutes: number;
  apps: AppUsageInput[];
}): Promise<GeminiResult> {
  // アプリ別内訳(アプリ名・パッケージ名・利用分数)を箇条書きにしてプロンプトへ
  // 渡す。一極集中の判断材料になるよう、利用時間の多い順に並べる。パッケージ名も
  // 載せるのは、表示名だけでは何のアプリか判別できないケース(端末固有の名前、
  // 同名の別アプリ)があるため。
  const sortedApps = [...input.apps].sort((a, b) => b.minutes - a.minutes);
  const appLines = sortedApps.length === 0
    ? "(記録なし)"
    : sortedApps
      .map((a) => `- ${a.name}${a.app_id ? ` [${a.app_id}]` : ""}: ${a.minutes}分`)
      .join("\n");

  const systemInstruction = [
    "あなたは保護者向けに、子どものスクリーンタイムからSNS・動画・ゲームとの付き合い方を講評する専門家です。",
    "SNS自体の利用を禁止・削減させることが目的ではなく、子どもが適切な距離感でSNSと付き合えるように促すことが目的です。",
    "子どもを断罪したり責めたりするトーンは避け、前向きで具体的な助言をしてください。",
    "出力はすべて日本語で、指定されたJSONスキーマの形式でのみ返してください。",
  ].join("\n");

  const prompt = [
    `対象の子ども: ${input.childName}`,
    `対象日: ${input.date}(この1日分のみのデータです。前日以前との比較や増減には触れないでください)`,
    `総利用時間: ${input.totalMinutes}分(下記アプリ別内訳の合計)`,
    "アプリ別内訳(利用時間が多い順):",
    appLines,
    "",
    "内訳の読み方:",
    "- 各行は「アプリの表示名 [Androidのパッケージ名]: 利用時間」です。" +
    "パッケージ名は、表示名だけでは何のアプリか分からないときの手がかりに使ってください。",
    "- どのアプリが「ドパガキ対象」かは、あなたがアプリ名とパッケージ名から判断してください。" +
    "ドパガキ対象とは、SNS・動画・ショート動画・ゲームなど、短時間で強い刺激が得られて" +
    "没入しやすく、つい長時間使ってしまうアプリを指します。",
    "- 記録は端末のアプリ利用時間そのものなので、学習アプリ・音楽・カメラ・地図・" +
    "連絡手段など、ドパガキ対象ではないアプリも含まれます。これらの利用時間を" +
    "依存の根拠にしないでください。",
    "- ブラウザのように用途が一つに定まらないアプリは、断定を避けて慎重に扱ってください。",
    "- 何のアプリか判断できない場合は、無理に分類せず言及も避けてください。",
    "- 内訳に無いアプリについては何も述べないでください。憶測でアプリ名を挙げるのは禁止です。",
    "",
    "以上をもとに、次の4つをJSONで生成してください。",
    "",
    "1. dopagaki_score (0-100の整数): 「ドパガキ指数」。ドパガキ対象アプリへの" +
    "依存・没入の深刻さを表す点数で、高いほど深刻です。" +
    "単純な利用時間の割合ではなく、アプリ別内訳から次の3点を総合して採点してください。" +
    "(a) ドパガキ対象アプリの絶対的な利用時間の長さ(長時間ほど高スコア)、" +
    "(b) 特定の1アプリへの一極集中の度合い(偏っているほど高スコア)、" +
    "(c) 総利用時間に占めるドパガキ対象アプリの割合。" +
    "総利用時間そのものが短い日は、割合が高くてもスコアを抑えめにしてください。" +
    "内訳が空(記録なし)の場合は0にしてください。",
    "2. score_reason (文字列): その点数にした理由を1-2文で。" +
    "どのアプリの何分をドパガキ対象と見たか、上の(a)(b)(c)のどれが効いたかを、" +
    "実際の数字を挙げて説明してください。保護者が読んで納得できる説明にしてください。",
    "3. summary (文字列): 上記の講評を2-3文程度で。特によく使われているアプリに触れつつ、" +
    "適切な距離感でのSNS利用を促すトーン。",
    "4. advice (文字列の配列、1-3件): 保護者が子どもに提案できる具体的なアクション。" +
    "内訳に実際に出てきたアプリに即した内容にしてください。",
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
            dopagaki_score: { type: "integer", minimum: 0, maximum: 100 },
            score_reason: { type: "string" },
            summary: { type: "string" },
            advice: { type: "array", items: { type: "string" } },
          },
          required: ["dopagaki_score", "score_reason", "summary", "advice"],
        },
      },
      // 実測(2026-09-10)で800では途中で切れてJSON.parseが失敗することを確認した
      // (advice配列の生成中に打ち切られた)。Gemini 3系は思考トークンもこの枠から
      // 消費するため、score+score_reason+summary+advice(最大3件)の分量に対して
      // 余裕を持たせる。
      generation_config: { max_output_tokens: 2500 },
    }),
  });

  if (!res.ok) {
    const text = await res.text();
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
  const score = Number(obj.dopagaki_score);
  const scoreReason = String(obj.score_reason ?? "");
  const summary = String(obj.summary ?? "");
  const advice = Array.isArray(obj.advice) ? obj.advice.map((a) => String(a)) : [];

  if (!Number.isFinite(score) || !summary) {
    throw new Error(`Gemini JSON output missing required fields: ${joined}`);
  }

  return { dopagaki_score: score, score_reason: scoreReason, summary, advice };
}
