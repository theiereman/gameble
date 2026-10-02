// Keeps a way out when the pack reveal fails: its code does not load, or it
// throws while rendering. Shows a short message and a link to the pack's
// page, which then shows the faces (the reveal comes once). Loaded with the
// application, not with the reveal, so it survives a failed chunk.
import { Component, type ReactNode } from "react"
import type { PackRevealStrings } from "./PackReveal"

type Props = { strings: Pick<PackRevealStrings, "failed" | "reload">; children?: ReactNode }

export default class RevealErrorBoundary extends Component<Props, { failed: boolean }> {
  state = { failed: false }

  static getDerivedStateFromError() {
    return { failed: true }
  }

  render() {
    if (!this.state.failed) return this.props.children
    return (
      <div className="pack-reveal pack-reveal--failed" role="alert">
        <p className="text-plate">{this.props.strings.failed}</p>
        <div className="pack-end">
          <a className="button button--secondary" href={window.location.pathname}>
            {this.props.strings.reload}
          </a>
        </div>
      </div>
    )
  }
}
