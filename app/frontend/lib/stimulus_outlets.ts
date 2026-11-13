import { Context, Multimap } from "@hotwired/stimulus"

type Module = { identifier: string; definition: { controllerConstructor: { outlets?: string[] } } }
type Router = { modules: Module[]; contexts: { identifier: string }[] }
type OutletObserver = { router: Router; identifier: string; outletDependencies: Multimap<string, string> }

const dependenciesByRouter = new WeakMap<Router, { count: number; dependencies: Multimap<string, string> }>()

function outletsOf(constructor: Module["definition"]["controllerConstructor"]): string[] {
  const ancestors: object[] = []
  for (let link: unknown = constructor; typeof link === "function"; link = Object.getPrototypeOf(link))
    ancestors.unshift(link)
  const outlets = new Set<string>()
  for (const ancestor of ancestors) {
    const declared: unknown = Object.getOwnPropertyDescriptor(ancestor, "outlets")?.value
    if (Array.isArray(declared)) declared.forEach((name: string) => outlets.add(name))
  }
  return [...outlets]
}

export function outletDependencies(router: Router): Multimap<string, string> {
  const modules = router.modules
  const cached = dependenciesByRouter.get(router)
  if (cached && cached.count === modules.length) return cached.dependencies
  const dependencies = new Multimap<string, string>()
  for (const module of modules)
    for (const outlet of outletsOf(module.definition.controllerConstructor)) dependencies.add(outlet, module.identifier)
  dependenciesByRouter.set(router, { count: modules.length, dependencies })
  return dependencies
}

function dependentContexts(this: OutletObserver): { identifier: string }[] {
  const identifiers = this.outletDependencies.getValuesForKey(this.identifier)
  if (identifiers.length === 0) return []
  return this.router.contexts.filter((context) => identifiers.includes(context.identifier))
}

function speedUp(observer: object): void {
  Object.defineProperty(observer, "outletDependencies", {
    configurable: true,
    get(this: OutletObserver) {
      return outletDependencies(this.router)
    },
  })
  Object.defineProperty(observer, "dependentContexts", { configurable: true, get: dependentContexts })
}

let installed = false

// Stimulus 3.2.2 rescans every registered controller and every connected one on each connect, quadratic on a page of cards.
export function connectControllersInLinearTime(): void {
  if (installed) return
  installed = true
  const connect = Context.prototype.connect
  let done = false
  Context.prototype.connect = function (this: Context) {
    if (!done) {
      speedUp(Object.getPrototypeOf((this as unknown as { outletObserver: object }).outletObserver) as object)
      done = true
    }
    connect.call(this)
  }
}
