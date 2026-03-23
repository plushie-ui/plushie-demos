/** A country record. */
export interface Country {
  name: string
  capital: string
  continent: string
  population: number
  area: number
}

/** Sample dataset: 50 countries with population and area. */
export const COUNTRIES: Country[] = [
  { name: "Argentina", capital: "Buenos Aires", continent: "South America", population: 46_000_000, area: 2_780_400 },
  { name: "Australia", capital: "Canberra", continent: "Oceania", population: 26_000_000, area: 7_692_024 },
  { name: "Austria", capital: "Vienna", continent: "Europe", population: 9_100_000, area: 83_879 },
  { name: "Bangladesh", capital: "Dhaka", continent: "Asia", population: 170_000_000, area: 147_570 },
  { name: "Belgium", capital: "Brussels", continent: "Europe", population: 11_600_000, area: 30_528 },
  { name: "Brazil", capital: "Brasilia", continent: "South America", population: 214_000_000, area: 8_515_767 },
  { name: "Canada", capital: "Ottawa", continent: "North America", population: 39_000_000, area: 9_984_670 },
  { name: "Chile", capital: "Santiago", continent: "South America", population: 19_500_000, area: 756_102 },
  { name: "China", capital: "Beijing", continent: "Asia", population: 1_412_000_000, area: 9_596_961 },
  { name: "Colombia", capital: "Bogota", continent: "South America", population: 51_000_000, area: 1_141_748 },
  { name: "Czech Republic", capital: "Prague", continent: "Europe", population: 10_800_000, area: 78_867 },
  { name: "Denmark", capital: "Copenhagen", continent: "Europe", population: 5_900_000, area: 43_094 },
  { name: "Egypt", capital: "Cairo", continent: "Africa", population: 104_000_000, area: 1_002_450 },
  { name: "Ethiopia", capital: "Addis Ababa", continent: "Africa", population: 120_000_000, area: 1_104_300 },
  { name: "Finland", capital: "Helsinki", continent: "Europe", population: 5_600_000, area: 338_424 },
  { name: "France", capital: "Paris", continent: "Europe", population: 68_000_000, area: 640_679 },
  { name: "Germany", capital: "Berlin", continent: "Europe", population: 84_000_000, area: 357_022 },
  { name: "Greece", capital: "Athens", continent: "Europe", population: 10_400_000, area: 131_957 },
  { name: "India", capital: "New Delhi", continent: "Asia", population: 1_428_000_000, area: 3_287_263 },
  { name: "Indonesia", capital: "Jakarta", continent: "Asia", population: 277_000_000, area: 1_904_569 },
  { name: "Iran", capital: "Tehran", continent: "Asia", population: 87_000_000, area: 1_648_195 },
  { name: "Ireland", capital: "Dublin", continent: "Europe", population: 5_100_000, area: 70_273 },
  { name: "Israel", capital: "Jerusalem", continent: "Asia", population: 9_800_000, area: 22_145 },
  { name: "Italy", capital: "Rome", continent: "Europe", population: 59_000_000, area: 301_340 },
  { name: "Japan", capital: "Tokyo", continent: "Asia", population: 125_000_000, area: 377_975 },
  { name: "Kenya", capital: "Nairobi", continent: "Africa", population: 54_000_000, area: 580_367 },
  { name: "Mexico", capital: "Mexico City", continent: "North America", population: 129_000_000, area: 1_964_375 },
  { name: "Morocco", capital: "Rabat", continent: "Africa", population: 37_000_000, area: 446_550 },
  { name: "Netherlands", capital: "Amsterdam", continent: "Europe", population: 17_600_000, area: 41_543 },
  { name: "New Zealand", capital: "Wellington", continent: "Oceania", population: 5_100_000, area: 268_021 },
  { name: "Nigeria", capital: "Abuja", continent: "Africa", population: 218_000_000, area: 923_768 },
  { name: "Norway", capital: "Oslo", continent: "Europe", population: 5_500_000, area: 323_802 },
  { name: "Pakistan", capital: "Islamabad", continent: "Asia", population: 230_000_000, area: 881_913 },
  { name: "Peru", capital: "Lima", continent: "South America", population: 33_700_000, area: 1_285_216 },
  { name: "Philippines", capital: "Manila", continent: "Asia", population: 115_000_000, area: 300_000 },
  { name: "Poland", capital: "Warsaw", continent: "Europe", population: 38_000_000, area: 312_696 },
  { name: "Portugal", capital: "Lisbon", continent: "Europe", population: 10_300_000, area: 92_212 },
  { name: "Russia", capital: "Moscow", continent: "Europe", population: 146_000_000, area: 17_098_242 },
  { name: "Saudi Arabia", capital: "Riyadh", continent: "Asia", population: 36_000_000, area: 2_149_690 },
  { name: "South Africa", capital: "Pretoria", continent: "Africa", population: 60_000_000, area: 1_221_037 },
  { name: "South Korea", capital: "Seoul", continent: "Asia", population: 52_000_000, area: 100_363 },
  { name: "Spain", capital: "Madrid", continent: "Europe", population: 47_400_000, area: 505_990 },
  { name: "Sweden", capital: "Stockholm", continent: "Europe", population: 10_500_000, area: 450_295 },
  { name: "Switzerland", capital: "Bern", continent: "Europe", population: 8_800_000, area: 41_285 },
  { name: "Thailand", capital: "Bangkok", continent: "Asia", population: 72_000_000, area: 513_120 },
  { name: "Turkey", capital: "Ankara", continent: "Asia", population: 85_000_000, area: 783_562 },
  { name: "Ukraine", capital: "Kyiv", continent: "Europe", population: 44_000_000, area: 603_500 },
  { name: "United Kingdom", capital: "London", continent: "Europe", population: 67_000_000, area: 243_610 },
  { name: "United States", capital: "Washington D.C.", continent: "North America", population: 331_000_000, area: 9_833_520 },
  { name: "Vietnam", capital: "Hanoi", continent: "Asia", population: 99_000_000, area: 331_212 },
]
