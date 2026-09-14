import "../../../core/models/destination.dart";

/// Sample content for previewing the real screens without Firestore, toggled
/// from the Profile tab in debug builds (`sampleDataProvider`). Real names,
/// with `popular`, `featured` and `hasAR` spread so every section has
/// something to show. No photography yet — every card falls back to the
/// placeholder tile rather than borrow a branding asset as a stand-in photo.
const sampleDestinations = <Destination>[
  Destination(
    id: "callao-cave",
    name: "Callao Cave",
    town: "Peñablanca",
    category: DestinationCategory.nature,
    description:
        "Seven chambers of limestone, one of them a chapel lit by a skylight "
        "the roof made itself.",
    history:
        "Excavations in the first chamber turned up a 67,000-year-old foot "
        "bone in 2007, the oldest human remains found in the Philippines. "
        "The chapel was built in the second chamber in the 1970s, and the "
        "184 steps up from the river were cut not long after.",
    coords: GeoPoint2(lat: 17.7017, lng: 121.8236),
    popular: true,
    featured: true,
    hasAR: true,
    tags: ["Caves", "Chapel", "Bats at dusk"],
    practical: PracticalInfo(
      entryFee: "PHP 40",
      openHours: "8am to 5pm daily",
      bestSeason: "December to May, when the river is low",
      accessibility: "184 steps to the entrance, no ramp",
    ),
    status: DestinationStatus.published,
  ),
  Destination(
    id: "palaui-island",
    name: "Palaui Island",
    town: "Santa Ana",
    category: DestinationCategory.nature,
    description: "A protected island at the province's tip, reached by boat.",
    history:
        "Named a protected landscape and seascape in 1994. The lighthouse on "
        "the cape was lit in 1892 and still marks the mouth of the Babuyan "
        "Channel.",
    coords: GeoPoint2(lat: 18.5497, lng: 122.1436),
    popular: true,
    featured: true,
    tags: ["Island", "Boat trip", "Hiking"],
    practical: PracticalInfo(
      entryFee: "PHP 50, plus the boat",
      openHours: "Boats leave San Vicente port from 6am",
      bestSeason: "March to June",
      accessibility: "A 20-minute boat ride, then trail walking",
    ),
    status: DestinationStatus.published,
  ),
  Destination(
    id: "basilica-minore-de-piat",
    name: "Basilica Minore de Piat",
    town: "Piat",
    category: DestinationCategory.church,
    description: "Home of Our Lady of Piat, the pilgrimage of the valley.",
    history:
        "The image of Our Lady of Piat arrived from Macau in 1604 and has "
        "been carried through the valley every June since. The church was "
        "raised to a basilica minore in 1997.",
    coords: GeoPoint2(lat: 17.7906, lng: 121.4783),
    tags: ["Pilgrimage", "Baroque", "June feast"],
    practical: PracticalInfo(
      entryFee: "Free",
      openHours: "6am to 7pm daily, Mass at 6am and 5pm",
      bestSeason: "June, for the Sambali festival",
      accessibility: "Level entrance, ramps at the side doors",
    ),
    popular: true,
    hasAR: true,
    status: DestinationStatus.published,
  ),
  Destination(
    id: "buntun-bridge",
    name: "Buntun Bridge",
    town: "Tuguegarao",
    category: DestinationCategory.landmark,
    description: "The longest river bridge in the country, over the Cagayan.",
    coords: GeoPoint2(lat: 17.6146, lng: 121.7080),
    status: DestinationStatus.published,
  ),
  Destination(
    id: "cape-engano-lighthouse",
    name: "Cape Engaño Lighthouse",
    town: "Santa Ana",
    category: DestinationCategory.heritage,
    description: "A Spanish-era lighthouse on a hill above two seas.",
    coords: GeoPoint2(lat: 18.5716, lng: 122.1595),
    popular: true,
    featured: true,
    status: DestinationStatus.published,
  ),
  Destination(
    id: "pinacanauan-river",
    name: "Pinacanauan River",
    town: "Peñablanca",
    category: DestinationCategory.nature,
    description: "Kayaks by day, and a river of bats at dusk.",
    coords: GeoPoint2(lat: 17.6975, lng: 121.8150),
    popular: true,
    status: DestinationStatus.published,
  ),
  Destination(
    id: "pancit-batil-patung",
    name: "Pancit Batil Patung",
    town: "Tuguegarao",
    category: DestinationCategory.food,
    description: "The capital's noodle, topped with a poached egg.",
    coords: GeoPoint2(lat: 17.6132, lng: 121.7270),
    popular: true,
    status: DestinationStatus.published,
  ),
  Destination(
    id: "anguib-beach",
    name: "Anguib Beach",
    town: "Santa Ana",
    category: DestinationCategory.nature,
    description: "White sand facing Palaui, quiet even in season.",
    coords: GeoPoint2(lat: 18.4967, lng: 122.1483),
    status: DestinationStatus.published,
  ),
  Destination(
    id: "iguig-calvary-hills",
    name: "Iguig Calvary Hills",
    town: "Iguig",
    category: DestinationCategory.church,
    description: "Life-size stations of the cross on a hill over the river.",
    coords: GeoPoint2(lat: 17.7517, lng: 121.7350),
    status: DestinationStatus.published,
  ),
  Destination(
    id: "cagayan-museum",
    name: "Cagayan Museum and Historical Research Center",
    town: "Tuguegarao",
    category: DestinationCategory.museum,
    description: "The province's story, from Callao's fossils to the present.",
    history:
        "Opened in 1973 beside the provincial capitol. Its collection begins "
        "with the Callao finds and runs through the Spanish tobacco monopoly "
        "to the province today.",
    coords: GeoPoint2(lat: 17.6120, lng: 121.7290),
    isMuseum: true,
    hasAR: true,
    tags: ["Archaeology", "Tobacco era", "Guided tours"],
    practical: PracticalInfo(
      entryFee: "Free",
      openHours: "Monday to Friday, 8am to 5pm",
      accessibility: "Single storey, wheelchair accessible",
    ),
    status: DestinationStatus.published,
  ),
];

/// Audio guide stops for the sample places, read aloud by the device: a
/// self-guided walk, arriving, what to look for at each stop, and where to
/// go next.
const sampleSegments = <String, List<Segment>>{
  "callao-cave": [
    Segment(
      id: "stop-01",
      title: "The steps from the river",
      order: 1,
      description: "Start at the foot of the stairs",
      ttsText:
          "Welcome to Callao Cave. The 184 steps ahead climb about sixty "
          "metres. Take them slowly; the view back over the Pinacanauan "
          "opens up halfway.",
    ),
    Segment(
      id: "stop-02",
      title: "The chapel chamber",
      order: 2,
      description: "First chamber, under the skylight",
      ttsText:
          "You are standing in the first chamber. The opening in the roof "
          "above the altar is natural; the chapel was built beneath it in the "
          "1970s. Sunday Mass is still said here.",
    ),
    Segment(
      id: "stop-03",
      title: "Where Callao Man was found",
      order: 3,
      description: "Look for the fenced dig near the wall",
      ttsText:
          "The fenced pit by the wall is where a foot bone was found in 2007, "
          "dated to sixty-seven thousand years ago. It is the oldest human "
          "remain found in the Philippines.",
    ),
    Segment(
      id: "stop-04",
      title: "Deeper chambers",
      order: 4,
      description: "Chambers two to seven, bring a light",
      ttsText:
          "The path continues through six more chambers. The floor is uneven "
          "and the last two are dark, so keep to the marked route. Bats "
          "leave the cave mouth at dusk if you stay until then.",
    ),
  ],
  "palaui-island": [
    Segment(
      id: "stop-01",
      title: "San Vicente port",
      order: 1,
      description: "Where the boats leave from",
      ttsText:
          "Boats to Palaui leave from San Vicente port from six in the "
          "morning. Register at the tourism desk first; the fee covers the "
          "island and the boat ride is paid separately.",
    ),
    Segment(
      id: "stop-02",
      title: "Punta Verde landing",
      order: 2,
      description: "The trail starts behind the huts",
      ttsText:
          "From the landing the lighthouse trail starts behind the huts and "
          "takes about forty minutes. The grass is tall in the wet season, "
          "so long trousers help.",
    ),
    Segment(
      id: "stop-03",
      title: "Cape Engaño lighthouse",
      order: 3,
      description: "The top of the island",
      ttsText:
          "Faro de Cabo Engaño was lit in 1892 and is still in service. From "
          "the base you can see the Dos Hermanas islets and, on a clear day, "
          "the Babuyan group to the north.",
    ),
  ],
  "basilica-minore-de-piat": [
    Segment(
      id: "stop-01",
      title: "The plaza",
      order: 1,
      description: "Start facing the facade",
      ttsText:
          "Stand in the plaza facing the facade. The brick church you see "
          "was finished in the 1700s; the bell tower to the left is later. "
          "Enter by the main door.",
    ),
    Segment(
      id: "stop-02",
      title: "Our Lady of Piat",
      order: 2,
      description: "The image above the altar",
      ttsText:
          "The image above the altar came from Macau in 1604 and is made of "
          "paper mache. Every June it is carried to Tuguegarao and back "
          "during the Sambali festival.",
    ),
    Segment(
      id: "stop-03",
      title: "The museum next door",
      order: 3,
      description: "Vestments and votive offerings",
      ttsText:
          "Leave by the side door for the small museum, which keeps the "
          "vestments and the votive offerings left over four centuries.",
    ),
  ],
  "cagayan-museum": [
    Segment(
      id: "stop-01",
      title: "Arriving",
      order: 1,
      description: "Beside the provincial capitol",
      ttsText:
          "The museum is the single-storey building beside the provincial "
          "capitol. Entry is free; sign the visitor book at the desk and "
          "start with the room on your left.",
    ),
    Segment(
      id: "stop-02",
      title: "The Callao finds",
      order: 2,
      description: "First room, left of the entrance",
      ttsText:
          "The first room holds casts of the Callao Cave finds and the stone "
          "tools found with them. The original bones are kept at the National "
          "Museum in Manila.",
    ),
    Segment(
      id: "stop-03",
      title: "The tobacco monopoly",
      order: 3,
      description: "Second room",
      ttsText:
          "For a century the whole valley grew tobacco for the Spanish crown. "
          "The presses, ledgers and the map of the monopoly's warehouses are "
          "in this room.",
    ),
  ],
};
