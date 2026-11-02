/*
 * Gravity Finance - gráfico del dashboard (ApexCharts).
 * Los datos llegan desde DashboardController en window.GF_GRAFICO.
 */
document.addEventListener('DOMContentLoaded', function () {
  const el = document.querySelector('#revenue-chart');
  const datos = window.GF_GRAFICO;
  if (!el || !datos) return;

  const colones = (v) => '₡' + Number(v).toLocaleString('es-CR', { maximumFractionDigits: 0 });

  new ApexCharts(el, {
    series: [
      { name: 'Ingresos', data: datos.ingresos },
      { name: 'Gastos', data: datos.gastos },
    ],
    chart: {
      type: 'bar',
      height: 220,
      toolbar: { show: false },
      zoom: { enabled: false },
      fontFamily: 'Plus Jakarta Sans, sans-serif',
    },
    colors: ['#072F1F', '#B4F105'],
    plotOptions: { bar: { horizontal: false, columnWidth: '48%', borderRadius: 0 } },
    dataLabels: { enabled: false },
    stroke: { show: true, width: 2, colors: ['transparent'] },
    legend: { show: false },
    grid: {
      borderColor: '#E9EFEF',
      strokeDashArray: 4,
      yaxis: { lines: { show: true } },
      xaxis: { lines: { show: false } },
    },
    xaxis: {
      categories: datos.etiquetas,
      labels: { style: { colors: '#6C7E75', fontSize: '11px', fontWeight: 500 } },
      axisBorder: { show: false },
      axisTicks: { show: false },
    },
    yaxis: { labels: { show: false } },
    fill: { opacity: 1 },
    tooltip: { y: { formatter: colones } },
  }).render();
});
