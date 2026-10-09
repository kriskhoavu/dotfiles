// Writes this OpenCode session's status to ~/.cache/ai-sessions/<pid>.json
// for the WezTerm agents hub. Linked into ~/.config/opencode/plugins/ by
// install.sh. Both permission.updated and permission.asked are handled: the
// pinned plugin types lag the runtime.
import { mkdirSync, unlinkSync, writeFileSync } from "node:fs"

export const AiSessions = async () => {
  const dir = `${process.env.XDG_CACHE_HOME ?? `${process.env.HOME}/.cache`}/ai-sessions`
  const file = `${dir}/${process.pid}.json`
  mkdirSync(dir, { recursive: true })

  const write = (status, cwd) => {
    try {
      writeFileSync(
        file,
        JSON.stringify({
          agent: "opencode",
          status,
          ts: Math.floor(Date.now() / 1000),
          cwd: cwd ?? process.cwd(),
          session_id: "",
        }),
      )
    } catch {}
  }
  const remove = () => {
    try { unlinkSync(file) } catch {}
  }

  write("idle")
  process.on("exit", remove)

  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.status":
          write(event.properties?.status?.type === "busy" ? "working" : "idle")
          break
        case "session.idle":
          write("idle")
          break
        case "permission.updated":
        case "permission.asked":
          write("blocked")
          break
        case "permission.replied":
          write("working")
          break
        case "message.updated":
          if (event.properties?.info?.role === "user") write("working")
          break
        case "session.deleted":
          remove()
          break
      }
    },
    "permission.ask": async () => write("blocked"),
    "tool.execute.before": async () => write("working"),
  }
}
