# First wave: what went live, and its photos

Imported into `project-lakbayan` on 2026-11-18 from `Lakbayan-content-intake.xlsx`
(31 destinations, all with approximate coordinates; see the README's
*Where the first wave stands*). A place was published only if it had a
cleared photo **and** a pin better than its town's centre; everything else is
a draft in the CMS.

**Photos used:** Wikimedia Commons files under their own licences, and the
province's own tourism photos (visit.cagayan.gov.ph / endlessfuncagayan.com),
approved for the app by the project team. The tourism office's written
permission for the latter is still to be filed. Photos from other sites
(Traveloka, Tripadvisor, a blog, PIA, DOT) were **not** used.

Each was resized to at most 1600px and stored at
`destinations/{id}/images/{ref}-01.jpg`.

> **Attribution is owed.** The Commons photos are CC BY / CC BY-SA: the
> photographer must be credited wherever the photo is shown. The app has no
> photo-credit field or credits screen yet; until it does, this list is the
> record, and the app needs one before a public release.

> **Re-importing unpublishes.** `import-content.mjs` writes every row as a
> draft, so running the first-wave sheet through it again takes these places
> out of the app until they are published again.

| Ref | Place | Town | Status | Photo | Credit | Licence |
|---|---|---|---|---|---|---|
| ALC-001 | Saint Philomene Church | Alcala | **published** | [Commons](https://commons.wikimedia.org/wiki/File:Saint_Philomene_the_Virgin_Parish_(Cagayan_Valley_Road,_Alcala,_Cagayan;_11-22-2022).jpg) | Patrickroque01 | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |
| AMU-001 | Cagayan Farm School and Agri-Tourism Center | Amulung | **published** | [province](https://visit.cagayan.gov.ph/wp-content/uploads/2022/04/257228813_425148779065505_5116004073748450200_n.jpg) | Cagayan Provincial Tourism Office | Province-owned; approved for the app |
| APA-001 | St. Peter Gonzales of Thelmo Parish Church | Aparri | **published** | [province](https://visit.cagayan.gov.ph/wp-content/uploads/2022/07/2020-10-26-6G6A7273-marianosayno-scaled.jpg) | Cagayan Provincial Tourism Office | Province-owned; approved for the app |
| BAG-001 | Archdiocesan Shrine and Parish of St. Joseph the Worker | Baggao | draft (no photo) | none cleared | — | — |
| BAG-002 | Laglagto Rock Formations | Baggao | draft (pin is the town centre) | none cleared | — | — |
| BAG-003 | Duba Cave and Underground River | Baggao | **published** | [province](https://visit.cagayan.gov.ph/wp-content/uploads/2022/05/2020-10-05-Group-17-DJI_0001_DJI_0009-9-images_0000-marianosayno-scaled.jpg) | Cagayan Provincial Tourism Office | Province-owned; approved for the app |
| BAG-004 | Bluewater Falls and Cave System | Baggao | draft (no photo) | none: only on visit.cagayan.gov.ph, whose certificate is invalid | — | — |
| BAG-005 | Lipit Canyon | Baggao | **published** | [province](https://visit.cagayan.gov.ph/wp-content/uploads/2022/05/2020-10-04-6G6A2303-marianosayno-scaled.jpg) | Cagayan Provincial Tourism Office | Province-owned; approved for the app |
| BAG-006 | Sierra Madre View Deck | Baggao | draft (pin is the town centre) | none cleared | — | — |
| BAL-001 | Cagayan Animal Breeding Center and Agri-Eco Tourism Park | Ballesteros | **published** | [province](https://endlessfuncagayan.com/wp-content/uploads/2022/04/Cagayan-Breeding-Sation-scaled.jpg) | Cagayan Provincial Tourism Office | Province-owned; approved for the app |
| BUG-001 | Saint Anne Parish Church (Buguey Church) | Buguey | **published** | [province](https://visit.cagayan.gov.ph/wp-content/uploads/2022/07/2020-10-25-6G6A7100-marianosayno-scaled.jpg) | Cagayan Provincial Tourism Office | Province-owned; approved for the app |
| CAM-001 | Sancta Maria Bell at San Jacinto de Polonia Parish | Camalaniugan | **published** | [province](https://visit.cagayan.gov.ph/wp-content/uploads/2022/04/2020-10-17-6G6A5687-marianosayno-scaled.jpg) | Cagayan Provincial Tourism Office | Province-owned; approved for the app |
| CLA-001 | Claveria Boulevard and Cove | Claveria | **published** | [Commons](https://commons.wikimedia.org/wiki/File:Boulevard_from_Cagayan.jpg) | KateleneCaacbay | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |
| GAT-001 | Cagayan Forest and Eco-Tourism Park | Gattaran | **published** | [province](https://endlessfuncagayan.com/wp-content/uploads/2022/04/Cagayan-Forest-Park.jpg) | Cagayan Provincial Tourism Office | Province-owned; approved for the app |
| GAT-002 | Saint Catherine of Alexandria Church | Gattaran | **published** | [province](https://visit.cagayan.gov.ph/wp-content/uploads/2022/07/2020-10-14-6G6A4793-marianosayno-scaled.jpg) | Cagayan Provincial Tourism Office | Province-owned; approved for the app |
| GON-001 | Tallag Beach and Rock Formations | Gonzaga | draft (no photo) | none: only on visit.cagayan.gov.ph, whose certificate is invalid | — | — |
| IGU-001 | Calvary Hills and Saint James the Apostle Church | Iguig | **published** | [Commons](https://commons.wikimedia.org/wiki/File:Calvary_Hills_Iguig_2.jpg) | Elmer Domingo | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |
| PEN-001 | Callao Cave and Eco-Tourism Park | Peñablanca | **published** | [Commons](https://commons.wikimedia.org/wiki/File:Callao_Cave_(9407095908).jpg) | mkirader | [CC BY 2.0](https://creativecommons.org/licenses/by/2.0) |
| PIA-001 | Basilica Minore of Our Lady of Piat | Piat | **published** | [Commons](https://commons.wikimedia.org/wiki/File:Basilica_of_Our_Lady_of_Piat.jpg) | JmKissme (changes by Rabanus Flavus) | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |
| STA-001 | Anguib Beach | Santa Ana | draft (no photo) | none cleared | — | — |
| STA-002 | Nangaramoan Beach Resort | Santa Ana | **published** | [province](https://visit.cagayan.gov.ph/wp-content/uploads/2022/05/2021-03-11-6G6A7933-marianosayno-scaled.jpg) | Cagayan Provincial Tourism Office | Province-owned; approved for the app |
| STA-003 | Pozorobo Beach | Santa Ana | draft (pin is the town centre) | [province](https://visit.cagayan.gov.ph/wp-content/uploads/2022/07/2021-03-11-6G6A8083-marianosayno-scaled.jpg) | Cagayan Provincial Tourism Office | Province-owned; approved for the app |
| STA-004 | Palaui Island and Cape Engaño Route | Santa Ana | **published** | [Commons](https://commons.wikimedia.org/wiki/File:Palaui_Island_Sta._Ana,_Cagayan.jpg) | Joyfulwandering | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |
| STA-005 | Crocodile Island | Santa Ana | draft (no photo) | none cleared | — | — |
| STA-006 | Buwacag Falls | Santa Ana | **published** | [province](https://visit.cagayan.gov.ph/wp-content/uploads/2022/05/2020-10-18-6G6A6114-marianosayno-scaled.jpg) | Cagayan Provincial Tourism Office | Province-owned; approved for the app |
| STA-007 | Casagan Firefly-Watching Site | Santa Ana | draft (no photo) | none cleared | — | — |
| TUA-001 | Holy Guardian Angels Parish Church and Spanish Belfry | Tuao | draft (no photo) | none cleared | — | — |
| TUG-001 | Cagayan Museum and Historical Research Center | Tuguegarao City | **published** | [Commons](https://commons.wikimedia.org/wiki/File:Cagayan_Museum,_Rizal_Park_monument_(Rizal_Street,_Tuguegarao,_Cagayan;_11-19-2022).jpg) | Patrickroque01 | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |
| TUG-002 | Saint Peter Metropolitan Cathedral | Tuguegarao City | **published** | [province](https://visit.cagayan.gov.ph/wp-content/uploads/2022/05/6G6A4145-Feb-23-2021-Mariano-Sayno-scaled.jpg) | Cagayan Provincial Tourism Office | Province-owned; approved for the app |
| TUG-003 | San Jacinto Chapel (Ermita de San Jacinto) | Tuguegarao City | draft (no photo) | none cleared | — | — |
| TUG-004 | Rizal Park | Tuguegarao City | draft (no photo) | none cleared | — | — |
