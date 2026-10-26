export function serverTemplate(html: string, doc: Document = document): HTMLTemplateElement {
  const template = doc.createElement("template")
  template.innerHTML = html
  return template
}
