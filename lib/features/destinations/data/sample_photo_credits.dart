/// Who took one of the sample photographs, and under what licence.
///
/// The photographs in `assets/images/samples/` are other people's work, used
/// under licences that ask for exactly this: the author's name, the licence,
/// and where the original lives. This list is what the app shows as credit
/// and what `assets/images/samples/CREDITS.md` repeats for somebody reading
/// the repository; a test holds the two and the files themselves together.
class SamplePhotoCredit {
  const SamplePhotoCredit({
    required this.asset,
    required this.place,
    required this.title,
    required this.author,
    required this.licence,
    required this.source,
    this.licenceUrl,
  });

  /// The bundled file, as `sampleDestinations` refers to it.
  final String asset;

  /// The sample place it illustrates.
  final String place;

  /// The file's name on Wikimedia Commons.
  final String title;

  final String author;

  /// Short name: "CC BY-SA 4.0", "Public domain".
  final String licence;

  /// The licence text. Null for public domain, which has none to link.
  final String? licenceUrl;

  /// The file's page on Wikimedia Commons.
  final String source;
}

/// Every sample photograph, in the order the places appear.
///
/// All from Wikimedia Commons, at the 960px width its own thumbnailer
/// produced and otherwise unmodified — no crop, no retouching. That matters
/// for the share-alike licences: a plain resize is generally treated as a
/// technical change, whereas a crop or an edit would be an adaptation that
/// has to be shared under the same licence. Keep them as they are.
///
/// **Anguib Beach has none.** Commons holds no photograph of it, and another
/// beach standing in for a real place would be a small lie in an app whose
/// job is telling people what is where.
const samplePhotoCredits = <SamplePhotoCredit>[
  SamplePhotoCredit(
    asset: "assets/images/samples/callao-cave.jpg",
    place: "Callao Cave",
    title: "Callao Cave (9407095908).jpg",
    author: "mkirader",
    licence: "CC BY 2.0",
    licenceUrl: "https://creativecommons.org/licenses/by/2.0",
    source:
        "https://commons.wikimedia.org/wiki/File:Callao_Cave_(9407095908).jpg",
  ),
  SamplePhotoCredit(
    asset: "assets/images/samples/palaui-island.jpg",
    place: "Palaui Island",
    title: "Palaui Island Sta. Ana, Cagayan.jpg",
    author: "Joyfulwandering",
    licence: "CC BY-SA 4.0",
    licenceUrl: "https://creativecommons.org/licenses/by-sa/4.0",
    source: "https://commons.wikimedia.org/wiki/File:Palaui_Island_Sta._Ana,_Cagayan.jpg",
  ),
  SamplePhotoCredit(
    asset: "assets/images/samples/basilica-minore-de-piat.jpg",
    place: "Basilica Minore de Piat",
    title: "Basilica of Our Lady of Piat.jpg",
    author: "JmKissme (changes by Rabanus Flavus)",
    licence: "CC BY-SA 4.0",
    licenceUrl: "https://creativecommons.org/licenses/by-sa/4.0",
    source: "https://commons.wikimedia.org/wiki/File:Basilica_of_Our_Lady_of_Piat.jpg",
  ),
  SamplePhotoCredit(
    asset: "assets/images/samples/buntun-bridge.jpg",
    place: "Buntun Bridge",
    title: "Buntun Bridge (Tuguegarao, Cagayan; 11-22-2022).jpg",
    author: "Patrickroque01",
    licence: "Public domain",
    source: "https://commons.wikimedia.org/wiki/File:Buntun_Bridge_(Tuguegarao,_Cagayan;_11-22-2022).jpg",
  ),
  SamplePhotoCredit(
    asset: "assets/images/samples/cape-engano-lighthouse.jpg",
    place: "Cape Engaño Lighthouse",
    title: "Cape Engano Lighthouse (Yvette Tan) - Flickr.jpg",
    author: "Yvette Tan",
    licence: "CC BY 2.0",
    licenceUrl: "https://creativecommons.org/licenses/by/2.0",
    source: "https://commons.wikimedia.org/wiki/File:Cape_Engano_Lighthouse_(Yvette_Tan)_-_Flickr.jpg",
  ),
  SamplePhotoCredit(
    asset: "assets/images/samples/pinacanauan-river.jpg",
    place: "Pinacanauan River",
    title: "Pinacanauan River 1.jpg",
    author: "Kathleen Mae Tugano",
    licence: "CC BY-SA 4.0",
    licenceUrl: "https://creativecommons.org/licenses/by-sa/4.0",
    source: "https://commons.wikimedia.org/wiki/File:Pinacanauan_River_1.jpg",
  ),
  SamplePhotoCredit(
    asset: "assets/images/samples/pancit-batil-patung.jpg",
    place: "Pancit Batil Patung",
    title: "Pancit Batil Patong.jpg",
    author: "Markadan",
    licence: "CC BY-SA 4.0",
    licenceUrl: "https://creativecommons.org/licenses/by-sa/4.0",
    source: "https://commons.wikimedia.org/wiki/File:Pancit_Batil_Patong.jpg",
  ),
  SamplePhotoCredit(
    asset: "assets/images/samples/iguig-calvary-hills.jpg",
    place: "Iguig Calvary Hills",
    title: "Calvary Hills Iguig 2.jpg",
    author: "Elmer Domingo",
    licence: "CC BY-SA 4.0",
    licenceUrl: "https://creativecommons.org/licenses/by-sa/4.0",
    source: "https://commons.wikimedia.org/wiki/File:Calvary_Hills_Iguig_2.jpg",
  ),
  SamplePhotoCredit(
    asset: "assets/images/samples/cagayan-museum.jpg",
    place: "Cagayan Museum and Historical Research Center",
    title:
        "Cagayan Museum, Rizal Park monument (Rizal Street, Tuguegarao, "
        "Cagayan; 11-19-2022).jpg",
    author: "Patrickroque01",
    licence: "CC BY-SA 4.0",
    licenceUrl: "https://creativecommons.org/licenses/by-sa/4.0",
    source: "https://commons.wikimedia.org/wiki/File:Cagayan_Museum,_Rizal_Park_monument_(Rizal_Street,_Tuguegarao,_Cagayan;_11-19-2022).jpg",
  ),
];
