import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/features/web_view/models/try_on_category.dart';

void main() {
  TryOnCategory resolve(String title, {String? url}) =>
      resolveTryOnCategory(title: title, url: url);

  test('the four the service accepts are all there is', () {
    expect(TryOnCategory.values.map((c) => c.wireName), [
      'golf',
      'athletics',
      'workout',
      'sports',
    ]);
  });

  test('reads the category out of the product name', () {
    expect(
      resolve(
        "Walter Hagen Men's Performance 11 Tailgate Print Golf Polo "
        "| Dick's Sporting Goods",
      ),
      TryOnCategory.golf,
    );
    expect(
      resolve("Nike Men's Dri-FIT Training Shorts"),
      TryOnCategory.workout,
    );
    expect(
      resolve("Brooks Men's Ghost 16 Running Shoes"),
      TryOnCategory.athletics,
    );
    expect(
      resolve("Nike Men's Pittsburgh Steelers Jersey"),
      TryOnCategory.sports,
    );
  });

  test('anything unrecognised is tried on as sportswear', () {
    expect(resolve("Men's Cotton Crew Neck Tee"), TryOnCategory.sports);
    expect(resolve(''), TryOnCategory.sports);
  });

  test("the shop's own name is not part of the product", () {
    // Every title on the site ends in "Dick's Sporting Goods"; matching on it
    // would make the suffix decide the category.
    expect(
      resolve("Under Armour Men's Rival Fleece Hoodie | Dick's Sporting Goods"),
      TryOnCategory.sports,
    );
  });

  test('a name that says nothing falls back to the page it came from', () {
    expect(
      resolve(
        "Walter Hagen Men's 11 Majors Polo",
        url: 'https://www.dickssportinggoods.com/f/mens-golf-apparel',
      ),
      TryOnCategory.golf,
    );
  });

  test('the title wins over the page it sits on', () {
    expect(
      resolve(
        "Men's Running Shoes",
        url: 'https://www.dickssportinggoods.com/f/mens-golf-apparel',
      ),
      TryOnCategory.athletics,
    );
  });

  test('a word inside another word is not a match', () {
    // "run" must not be found in "trunks", nor "tour" in "contour".
    expect(resolve("Speedo Men's Swim Trunks"), TryOnCategory.sports);
    expect(resolve('Contour Fit Cap'), TryOnCategory.sports);
  });

  test('the more specific category wins where two could apply', () {
    expect(resolve("Men's Golf Training Polo"), TryOnCategory.golf);
    expect(resolve('Football Training Jersey'), TryOnCategory.sports);
  });
}
