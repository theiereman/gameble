import type { TopBarPanel } from "./events"

export type TopBarState = {
  standard: string
  special: string
  bell: string
  menuBadge: string
  capsules: string
  friends: string
  trades: string
  avatar: string
}

type Readable = Pick<ParentNode, "querySelector">
type PanelHost = Pick<ParentNode, "querySelector" | "querySelectorAll">

const AVATAR_PIXELS = 108

const PANELS: Record<TopBarPanel, string> = { bell: "#bell-panel", menu: "#phone-menu-panel" }

const textOf = (root: Readable, selector: string): string => root.querySelector(selector)?.textContent?.trim() ?? ""

const countOf = (text: string): number => Number(text.replace(/\D/g, ""))

function capsulesBadge(standard: string, special: string): string {
  const capsules = countOf(standard) + countOf(special)
  return capsules > 0 ? String(capsules) : ""
}

export function readCounts(root: Readable): Omit<TopBarState, "avatar"> {
  const bell = root.querySelector<HTMLElement>("[data-bell-target=count]")
  const standard = textOf(root, ".bank-counter__item:not(.bank-counter__item--special) .bank-counter__count")
  const special = textOf(root, ".bank-counter__item--special .bank-counter__count")
  return {
    standard,
    special,
    bell: bell && !bell.hidden ? (bell.textContent?.trim() ?? "") : "",
    menuBadge: textOf(root, "#phone-menu-badge .phone-menu__badge"),
    capsules: capsulesBadge(standard, special),
    friends: textOf(root, "#tab-invitations-badge .tab-bar__badge"),
    trades: textOf(root, "#tab-trades-badge .tab-bar__badge"),
  }
}

export function anyDialogOpen(root: Readable): boolean {
  return root.querySelector("dialog[open]") !== null
}

export function sameState(first: TopBarState | null, second: TopBarState): boolean {
  if (!first) return false
  return (Object.keys(second) as Array<keyof TopBarState>).every((key) => first[key] === second[key])
}

export function closePanels(root: PanelHost): void {
  root.querySelectorAll<HTMLElement>("[popover]:popover-open").forEach((panel) => panel.hidePopover())
}

// A tap on the native bar is outside the web view, so a panel's light dismiss never sees it: the panel's own control toggles it.
export function togglePanel(root: PanelHost, wanted: TopBarPanel | null): void {
  const panel = wanted ? root.querySelector<HTMLElement>(PANELS[wanted]) : null
  const wasOpen = panel?.matches(":popover-open") ?? false
  closePanels(root)
  if (panel && !wasOpen) panel.showPopover()
}

export function oncePerTask(run: () => void, defer: (task: () => void) => void = (task) => setTimeout(task, 0)) {
  let waiting = false
  return (): void => {
    if (waiting) return
    waiting = true
    defer(() => {
      waiting = false
      run()
    })
  }
}

export function cachedBySource(rasterize: (source: string) => Promise<string>) {
  const rendered = new Map<string, string>()
  return async (source: string): Promise<string> => {
    const known = rendered.get(source)
    if (known !== undefined) return known
    try {
      const image = await rasterize(source)
      rendered.set(source, image)
      return image
    } catch {
      return ""
    }
  }
}

async function svgToPng(source: string): Promise<string> {
  const image = new Image()
  image.src = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(source)}`
  await image.decode()
  const canvas = document.createElement("canvas")
  canvas.width = AVATAR_PIXELS
  canvas.height = AVATAR_PIXELS
  const context = canvas.getContext("2d")
  if (!context) return ""
  context.imageSmoothingEnabled = false
  context.drawImage(image, 0, 0, AVATAR_PIXELS, AVATAR_PIXELS)
  return canvas.toDataURL("image/png")
}

const avatarPng = cachedBySource(svgToPng)

// An SVG drawn as an image has no page around it to inherit the colour from.
export async function readAvatar(root: Readable): Promise<string> {
  const svg = root.querySelector<SVGSVGElement>(".player-chip__avatar")
  if (!svg) return ""
  const source = new XMLSerializer().serializeToString(svg)
  return avatarPng(source.replaceAll("currentColor", getComputedStyle(svg).color))
}
