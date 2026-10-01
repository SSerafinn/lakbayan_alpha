# Sample photograph credits

The photographs in this folder illustrate the **debug sample preview** only
(`sampleDataProvider`, toggled from the Profile tab). They are not the
province's content and they are not used for real destinations, which carry
their own photographs in Cloud Storage.

Every one is somebody else's work, taken from
[Wikimedia Commons](https://commons.wikimedia.org) and used under the licence
its author chose. Each is the 960px-wide copy Commons' own thumbnailer
produced and is otherwise **unmodified** — not cropped, not retouched.

| File | Place | Author | Licence | Original |
|---|---|---|---|---|
| `callao-cave.jpg` | Callao Cave | mkirader | [CC BY 2.0](https://creativecommons.org/licenses/by/2.0) | [Callao Cave (9407095908).jpg](https://commons.wikimedia.org/wiki/File:Callao_Cave_(9407095908).jpg) |
| `palaui-island.jpg` | Palaui Island | Joyfulwandering | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) | [Palaui Island Sta. Ana, Cagayan.jpg](https://commons.wikimedia.org/wiki/File:Palaui_Island_Sta._Ana,_Cagayan.jpg) |
| `basilica-minore-de-piat.jpg` | Basilica Minore de Piat | JmKissme (changes by Rabanus Flavus) | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) | [Basilica of Our Lady of Piat.jpg](https://commons.wikimedia.org/wiki/File:Basilica_of_Our_Lady_of_Piat.jpg) |
| `buntun-bridge.jpg` | Buntun Bridge | Patrickroque01 | Public domain | [Buntun Bridge (Tuguegarao, Cagayan; 11-22-2022).jpg](https://commons.wikimedia.org/wiki/File:Buntun_Bridge_(Tuguegarao,_Cagayan;_11-22-2022).jpg) |
| `cape-engano-lighthouse.jpg` | Cape Engaño Lighthouse | Yvette Tan | [CC BY 2.0](https://creativecommons.org/licenses/by/2.0) | [Cape Engano Lighthouse (Yvette Tan) - Flickr.jpg](https://commons.wikimedia.org/wiki/File:Cape_Engano_Lighthouse_(Yvette_Tan)_-_Flickr.jpg) |
| `pinacanauan-river.jpg` | Pinacanauan River | Kathleen Mae Tugano | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) | [Pinacanauan River 1.jpg](https://commons.wikimedia.org/wiki/File:Pinacanauan_River_1.jpg) |
| `pancit-batil-patung.jpg` | Pancit Batil Patung | Markadan | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) | [Pancit Batil Patong.jpg](https://commons.wikimedia.org/wiki/File:Pancit_Batil_Patong.jpg) |
| `iguig-calvary-hills.jpg` | Iguig Calvary Hills | Elmer Domingo | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) | [Calvary Hills Iguig 2.jpg](https://commons.wikimedia.org/wiki/File:Calvary_Hills_Iguig_2.jpg) |
| `cagayan-museum.jpg` | Cagayan Museum and Historical Research Center | Patrickroque01 | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) | [Cagayan Museum, Rizal Park monument (Rizal Street, Tuguegarao, Cagayan; 11-19-2022).jpg](https://commons.wikimedia.org/wiki/File:Cagayan_Museum,_Rizal_Park_monument_(Rizal_Street,_Tuguegarao,_Cagayan;_11-19-2022).jpg) |

## What the licences ask

- **CC BY 2.0** and **CC BY-SA 4.0** require credit to the author, a link to
  the licence, and a note of any changes. This table is that credit, and the
  app shows the same list under Profile → Photo credits.
- **CC BY-SA** additionally requires that an *adapted* version be shared under
  the same licence. A plain resize is generally treated as a technical change
  rather than an adaptation, which is why these are kept exactly as Commons
  served them. **Cropping or editing one would be an adaptation**, and the
  edited file would then have to be offered under CC BY-SA too. This is a
  developer's reading, not legal advice — worth a proper check before any of
  these ships in a public release.
- **Public domain** asks for nothing. The author is credited anyway.

## Keeping this honest

`lib/features/destinations/data/sample_photo_credits.dart` is the list the app
reads. `test/features/destinations/sample_photos_test.dart` fails if a sample
photograph has no credit, if a credit points at a file that is not here, or if
this document leaves one out.

To add or replace a photograph: use one whose licence permits reuse (CC0,
public domain, CC BY, CC BY-SA), add it to that Dart list and to the table
above, and never substitute a different place for the one named.

**Anguib Beach has no photograph.** Commons holds none, so its sample card
keeps the placeholder rather than show somewhere else under its name.
