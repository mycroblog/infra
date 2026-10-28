// メーリングリストのアドレス宛のメールを、所属メンバーの転送先アドレスへ配送する。
// MAILING_LISTS: {"<list address>": ["<member address>", ...]}
// 転送先は Email Routing で確認済みのアドレスである必要がある。

const LOOP_HEADER = "X-Mycroblog-Mailing-List";

export default {
  async email(message, env) {
    const list = message.to.toLowerCase();
    const recipients = JSON.parse(env.MAILING_LISTS)[list];

    if (!recipients?.length) {
      message.setReject("Unknown mailing list");
      return;
    }
    // 転送先にリストのアドレスが含まれていた場合の無限ループを防ぐ
    if (message.headers.has(LOOP_HEADER)) {
      message.setReject("Mail loop detected");
      return;
    }

    const headers = new Headers({ [LOOP_HEADER]: list });
    const results = await Promise.allSettled(recipients.map((to) => message.forward(to, headers)));

    const failures = results.filter((r) => r.status === "rejected");
    for (const failure of failures) {
      console.error(`failed to forward mail for ${list}:`, failure.reason);
    }
    // 1 件も届かなかった場合は送信元にエラーを返す
    if (failures.length === recipients.length) {
      throw new Error(`failed to forward mail for ${list} to all recipients`);
    }
  },
};
