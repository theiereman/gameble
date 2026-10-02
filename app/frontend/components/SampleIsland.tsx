// A sample React island (AD-16). Its data and every visible string come from Rails as props.
export type SampleIslandProps = {
  data: { season: number }
  strings: { heading: string; season: string }
}

export default function SampleIsland({ data, strings }: SampleIslandProps) {
  return (
    <section className="sample-island">
      <h2>{strings.heading}</h2>
      <p>
        {strings.season} {data.season}
      </p>
    </section>
  )
}
