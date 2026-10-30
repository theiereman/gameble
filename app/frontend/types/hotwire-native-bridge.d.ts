declare module "@hotwired/hotwire-native-bridge" {
  import { Controller } from "@hotwired/stimulus"

  export type BridgeMessage = { id: string; component: string; event: string; data: Record<string, unknown> }

  export class BridgeComponent<E extends Element = HTMLElement> extends Controller<E> {
    static component: string
    readonly enabled: boolean
    send(event: string, data?: Record<string, unknown>, callback?: (message: BridgeMessage) => void): void
  }
}
