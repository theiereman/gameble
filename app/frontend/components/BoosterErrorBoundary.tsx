// Keeps a way out when the booster island fails: its code does not load,
// or it throws while rendering. Shows a short message (any pack already
// opened is in the collection) and a link reloading the whole page: a
// Turbo visit would keep the failed import. Loaded with the application,
// not with the island, so it survives a failed chunk.
import { Component, type ReactNode } from "react"

type Props = { strings: { islandFailed: string; reload: string }; children?: ReactNode }

export default class BoosterErrorBoundary extends Component<Props, { failed: boolean }> {
  state = { failed: false }

  static getDerivedStateFromError() {
    return { failed: true }
  }

  render() {
    if (!this.state.failed) return this.props.children
    return (
      <div className="booster booster--failed" role="alert">
        <p className="panel">{this.props.strings.islandFailed}</p>
        {/* A full page load: a Turbo visit would keep the failed chunk's import. */}
        <a className="button button--secondary" href={window.location.pathname} data-turbo="false">
          {this.props.strings.reload}
        </a>
      </div>
    )
  }
}
