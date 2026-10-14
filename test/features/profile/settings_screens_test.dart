import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/app_settings.dart";
import "package:lakbayan/core/theme/app_icons.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/destinations/presentation/province_notice.dart";
import "package:lakbayan/features/guides/domain/guide_providers.dart";
import "package:lakbayan/features/profile/data/settings_repository.dart";
import "package:lakbayan/features/profile/domain/settings_providers.dart";
import "package:lakbayan/features/profile/presentation/help_screen.dart";
import "package:lakbayan/features/profile/presentation/policy_screen.dart";

void main() {
  late List<Uri> launched;

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    // Factories, not streams: Riverpod retries a provider that failed, and
    // a retry listens again — which a single-use stream refuses.
    Stream<AppSettings?> Function()? app,
    Stream<PolicySettings?> Function()? policies,
    bool canLaunch = true,
  }) async {
    launched = [];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith(
            (ref) => app?.call() ?? Stream<AppSettings?>.value(null),
          ),
          policiesProvider.overrideWith(
            (ref) => policies?.call() ?? Stream<PolicySettings?>.value(null),
          ),
          contactLauncherProvider.overrideWithValue((uri) async {
            launched.add(uri);
            return canLaunch;
          }),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group("emergencyLines", () {
    test("adds 911 after the province's lines", () {
      final lines = emergencyLines(const [
        Hotline(label: "MDRRMO Peñablanca", number: "0917 555 0101"),
      ]);
      expect(lines.map((l) => l.number), ["0917 555 0101", "911"]);
    });

    test("does not list 911 twice", () {
      final lines = emergencyLines(const [
        Hotline(label: "Emergency", number: "9-1-1"),
      ]);
      expect(lines, hasLength(1));
    });
  });

  group("reachUri", () {
    test("calls a short emergency code", () {
      expect(reachUri("911"), Uri(scheme: "tel", path: "911"));
      expect(reachUri(" 143 "), Uri(scheme: "tel", path: "143"));
    });

    test("leaves a whole number and an address to contactUri", () {
      expect(
        reachUri("0917 555 0101"),
        Uri(scheme: "tel", path: "09175550101"),
      );
      expect(reachUri("tourism@cagayan.gov.ph")?.scheme, "mailto");
      expect(reachUri("Capitol, Tuguegarao"), isNull);
    });
  });

  group("Help", () {
    const settings = AppSettings(
      contact: OfficeContact(
        office: "Cagayan Provincial Tourism Office",
        phone: "(078) 304 1234",
        email: "tourism@cagayan.gov.ph",
        hours: "Mon to Fri, 8 to 5",
      ),
      hotlines: [Hotline(label: "MDRRMO Peñablanca", number: "0917 555 0101")],
    );

    testWidgets("lists the province's lines, then 911", (tester) async {
      await pump(tester, const HelpScreen(), app: () => Stream.value(settings));

      expect(find.text("MDRRMO Peñablanca"), findsOneWidget);
      expect(find.text("0917 555 0101"), findsOneWidget);
      expect(find.text("National emergency"), findsOneWidget);
      expect(find.text("Cagayan Provincial Tourism Office"), findsOneWidget);
      expect(find.text("Mon to Fri, 8 to 5"), findsOneWidget);
    });

    testWidgets("a line calls its number", (tester) async {
      await pump(tester, const HelpScreen(), app: () => Stream.value(settings));

      await tester.tap(find.text("MDRRMO Peñablanca"));
      await tester.tap(find.text("National emergency"));
      await tester.pumpAndSettle();
      expect(launched, [
        Uri(scheme: "tel", path: "09175550101"),
        Uri(scheme: "tel", path: "911"),
      ]);
    });

    testWidgets("says the number when nothing can dial it", (tester) async {
      await pump(
        tester,
        const HelpScreen(),
        app: () => Stream.value(settings),
        canLaunch: false,
      );

      await tester.tap(find.text("National emergency"));
      await tester.pumpAndSettle();
      expect(find.text("No app here can open that. It's 911."), findsOneWidget);
    });

    testWidgets("offline and never loaded: 911, and why the rest is missing", (
      tester,
    ) async {
      await pump(
        tester,
        const HelpScreen(),
        app: () => Stream.error(const SettingsNotYetLoaded()),
      );

      expect(find.text("National emergency"), findsOneWidget);
      expect(
        find.textContaining("load the first time you're online"),
        findsOneWidget,
      );
    });

    testWidgets("nothing written yet says so", (tester) async {
      await pump(tester, const HelpScreen());

      expect(find.text("National emergency"), findsOneWidget);
      expect(
        find.text("The tourism office hasn't added its contact details yet."),
        findsOneWidget,
      );
    });
  });

  group("Policies", () {
    final policies = PolicySettings(
      privacy: "We collect what you save.\n\nWe never sell it.",
      privacyUpdatedAt: DateTime(2026, 10, 7),
    );

    testWidgets("shows the text as paragraphs, with its date", (tester) async {
      await pump(
        tester,
        const PolicyScreen(policy: Policy.privacy),
        policies: () => Stream.value(policies),
      );

      expect(find.text("Privacy policy"), findsOneWidget);
      expect(find.text("Last updated 7 Oct 2026"), findsOneWidget);
      expect(find.text("We collect what you save."), findsOneWidget);
      expect(find.text("We never sell it."), findsOneWidget);
    });

    testWidgets("an unwritten text says so", (tester) async {
      await pump(
        tester,
        const PolicyScreen(policy: Policy.terms),
        policies: () => Stream.value(policies),
      );

      expect(
        find.text("The province hasn't published its terms of use yet."),
        findsOneWidget,
      );
    });

    testWidgets("offline and never loaded says so, not 'unpublished'", (
      tester,
    ) async {
      await pump(
        tester,
        const PolicyScreen(policy: Policy.privacy),
        policies: () => Stream.error(const SettingsNotYetLoaded()),
      );

      expect(
        find.textContaining("loads the first time you're online"),
        findsOneWidget,
      );
      expect(find.textContaining("hasn't published"), findsNothing);
    });

    test("paragraphs split on blank lines and keep single breaks", () {
      expect(paragraphs("One\nstill one\r\n\r\n  \nTwo\n\n"), [
        "One\nstill one",
        "Two",
      ]);
    });
  });

  group("Explore notice", () {
    Stream<AppSettings?> notice(String text, {DateTime? until}) => Stream.value(
      AppSettings(
        announcement: Announcement(text: text, until: until),
      ),
    );

    testWidgets("shows a live notice and its last day", (tester) async {
      final now = DateTime.now();
      // Stored as the midnight after the last day, as the CMS writes it.
      final until = DateTime(now.year, now.month, now.day + 3);
      final lastDay = until.subtract(const Duration(days: 1));
      await pump(
        tester,
        const ProvinceNotice(),
        app: () => notice("Callao Cave is closed for repairs.", until: until),
      );

      expect(find.text("Callao Cave is closed for repairs."), findsOneWidget);
      expect(find.textContaining("Until ${lastDay.day} "), findsOneWidget);
    });

    testWidgets("shows nothing once it has ended", (tester) async {
      await pump(
        tester,
        const ProvinceNotice(),
        app: () => notice(
          "Typhoon advisory",
          until: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );

      expect(find.text("Typhoon advisory"), findsNothing);
    });

    testWidgets("shows nothing for a cleared text", (tester) async {
      await pump(tester, const ProvinceNotice(), app: () => notice("   "));

      // No empty card left behind.
      expect(find.byIcon(AppIcons.info), findsNothing);
    });
  });
}
