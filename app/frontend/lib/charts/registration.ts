import {
  BarController,
  BarElement,
  CategoryScale,
  Chart,
  LinearScale,
  LineController,
  LineElement,
  PointElement,
  ScatterController,
  Tooltip,
} from "chart.js"

Chart.register(
  BarController,
  BarElement,
  LineController,
  LineElement,
  PointElement,
  ScatterController,
  CategoryScale,
  LinearScale,
  Tooltip,
)

export { Chart }
