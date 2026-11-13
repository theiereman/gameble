// @vitest-environment happy-dom
import { Application, Controller } from "@hotwired/stimulus"
import { afterEach, describe, expect, it } from "vitest"
import { serverTemplate } from "./server_html"
import { connectControllersInLinearTime } from "./stimulus_outlets"

class ChildController extends Controller {
  static values = { label: String }
  declare readonly labelValue: string
}

class ParentController extends Controller {
  static outlets = ["child"]
  declare readonly childOutlets: ChildController[]
}

class SpecialParentController extends ParentController {
  static outlets = ["leaf"]
  declare readonly leafOutlets: Controller[]
}

class LeafController extends Controller {}

const tick = (): Promise<void> => new Promise((resolve) => setTimeout(resolve, 0))

describe("connectControllersInLinearTime", () => {
  let application: Application

  afterEach(() => {
    application.stop()
    document.body.replaceChildren()
  })

  async function start(html: string): Promise<void> {
    connectControllersInLinearTime()
    document.body.replaceChildren(serverTemplate(html).content)
    application = Application.start()
    application.register("child", ChildController)
    application.register("parent", ParentController)
    application.register("special-parent", SpecialParentController)
    application.register("leaf", LeafController)
    await tick()
  }

  it("still finds outlets present when the parent connects", async () => {
    await start(`
      <div data-controller="parent" data-parent-child-outlet=".child"></div>
      <div class="child" data-controller="child" data-child-label-value="a"></div>`)
    const parent = application.getControllerForElementAndIdentifier(
      document.querySelector("[data-controller=parent]")!,
      "parent",
    ) as ParentController
    expect(parent.childOutlets.map((child) => child.labelValue)).toEqual(["a"])
  })

  it("finds an outlet that connects after its parent", async () => {
    await start(`<div data-controller="parent" data-parent-child-outlet=".child"></div>`)
    document.body.append(
      serverTemplate(`<div class="child" data-controller="child" data-child-label-value="late"></div>`).content,
    )
    await tick()
    const parent = application.getControllerForElementAndIdentifier(
      document.querySelector("[data-controller=parent]")!,
      "parent",
    ) as ParentController
    expect(parent.childOutlets.map((child) => child.labelValue)).toEqual(["late"])
  })

  it("reads outlets a controller inherits as well as its own", async () => {
    await start(`
      <div data-controller="special-parent" data-special-parent-child-outlet=".child" data-special-parent-leaf-outlet=".leaf"></div>
      <div class="child" data-controller="child" data-child-label-value="b"></div>
      <div class="leaf" data-controller="leaf"></div>`)
    const parent = application.getControllerForElementAndIdentifier(
      document.querySelector("[data-controller=special-parent]")!,
      "special-parent",
    ) as SpecialParentController
    expect(parent.childOutlets.map((child) => child.labelValue)).toEqual(["b"])
    expect(parent.leafOutlets).toHaveLength(1)
  })
})
