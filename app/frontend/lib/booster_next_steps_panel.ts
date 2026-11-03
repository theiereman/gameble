export type NextStepsFrame = HTMLElement & { reload(): void }

const absolute = (url: string): string => new URL(url, document.baseURI).href

export function showNextSteps(panel: HTMLElement, frame: NextStepsFrame, url: string, shown: boolean): void {
  if (shown === !panel.hidden) return
  panel.hidden = !shown
  if (!shown) return
  const loaded = frame.getAttribute("src")
  if (loaded !== null && absolute(loaded) === absolute(url)) frame.reload()
  else frame.setAttribute("src", url)
}
