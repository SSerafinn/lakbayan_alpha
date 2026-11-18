import { describe, expect, it } from "vitest";
import glyphData from "../../../design/category-glyphs.json";
import {
  CATEGORY_GLYPHS,
  OTHER_GLYPH,
  allCategories,
  categoryIdFor,
  categoryInfo,
  categoryName,
  categoryProblem,
  categoryUsage,
  cleanCategories,
  suggestPlural,
  type CustomCategory,
} from "./categories";
import { cleanSubcategories } from "./settings";

const resort: CustomCategory = {
  id: "resort",
  name: "Resort",
  plural: "Resorts",
  glyph: "swimming-pool",
  look: "nature",
};

describe("the icon list", () => {
  it("reads every icon from the shared file, with unique names", () => {
    expect(CATEGORY_GLYPHS).toHaveLength(glyphData.glyphs.length);
    const names = CATEGORY_GLYPHS.map((g) => g.name);
    expect(new Set(names).size).toBe(names.length);
    expect(CATEGORY_GLYPHS.find((g) => g.name === "umbrella")?.codepoint).toBe(0xe684);
  });
});

describe("allCategories and lookups", () => {
  it("lists the six first, then the added ones in order", () => {
    const ids = allCategories([resort]).map((c) => c.id);
    expect(ids.slice(0, 6)).toEqual(["church", "nature", "heritage", "museum", "food", "landmark"]);
    expect(ids[6]).toBe("resort");
  });

  it("gives an added category its icon and borrowed colours", () => {
    expect(categoryInfo("resort", [resort])).toMatchObject({
      name: "Resort",
      plural: "Resorts",
      codepoint: 0xecb6,
      look: "nature",
      builtIn: false,
    });
  });

  it("falls back for a category that no longer exists", () => {
    expect(categoryInfo("gone", [resort])).toBeNull();
    expect(categoryName("gone", [resort])).toBe("gone");
    expect(categoryName("church", [])).toBe("Church");
  });

  it("draws an unknown icon name as the app's Other glyph", () => {
    expect(categoryInfo("x", [{ ...resort, id: "x", glyph: "nope" }])?.codepoint).toBe(OTHER_GLYPH);
  });
});

describe("categoryProblem", () => {
  it("accepts a complete, new category", () => {
    expect(categoryProblem(resort, [])).toBeNull();
  });

  it("asks for each missing part", () => {
    expect(categoryProblem({ ...resort, name: " " }, [])).toMatch(/name/);
    expect(categoryProblem({ ...resort, plural: "" }, [])).toMatch(/plural/);
    expect(categoryProblem({ ...resort, glyph: "" }, [])).toMatch(/icon/);
  });

  it("refuses the six, by id or by name", () => {
    expect(categoryProblem({ ...resort, id: "nature", name: "Nature" }, [])).toMatch(/six/);
    expect(categoryProblem({ ...resort, id: "museums", name: "Museum" }, [])).toMatch(/six/);
    expect(categoryProblem({ ...resort, id: "unknown", name: "Unknown" }, [])).toMatch(/six/);
  });

  it("refuses a second category with the same id or name", () => {
    expect(categoryProblem({ ...resort, plural: "More resorts" }, [resort])).toMatch(/already/);
  });
});

describe("helpers", () => {
  it("makes an id from the name", () => {
    expect(categoryIdFor("Hot Spring")).toBe("hot-spring");
  });

  it("suggests a plural", () => {
    expect(suggestPlural("Resort")).toBe("Resorts");
    expect(suggestPlural("Gallery")).toBe("Galleries");
    expect(suggestPlural("Beach")).toBe("Beaches");
    expect(suggestPlural("")).toBe("");
  });

  it("drops what cannot be saved, and duplicates", () => {
    const kept = cleanCategories([
      { ...resort, name: "  Resort ", plural: " Resorts " },
      { ...resort },
      { ...resort, id: "x", name: "", glyph: "camera" },
    ]);
    expect(kept).toEqual([resort]);
  });

  it("counts places per category", () => {
    const usage = categoryUsage([{ category: "resort" }, { category: "resort" }, { category: "church" }]);
    expect(usage.get("resort")).toBe(2);
    expect(usage.get("church")).toBe(1);
  });

  it("keeps subcategories only for categories that exist", () => {
    expect(
      cleanSubcategories(
        { resort: ["Beach resort"], gone: ["Old"], church: [] },
        ["church", "resort"],
      ),
    ).toEqual({ resort: ["Beach resort"] });
  });
});
