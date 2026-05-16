// Reusable navigation: onboard a fresh Sprout (age 3) or any age, land in wizard.
// All coordinates are for the 414x896 viewport, mapped from recon screenshots.
import { boot, shot, clickFrac, clickXY } from './lib.mjs';

// age -> grid coordinate (3x3 grid, ages 3-11)
const AGE_XY = {
  3: [80, 335], 4: [207, 335], 5: [334, 335],
  6: [80, 461], 7: [207, 461], 8: [334, 461],
  9: [80, 587], 10: [207, 587], 11: [334, 587],
};

// Onboard from a clean storage state through to the wizard's first screen.
// Returns { browser, page, errors }.
export async function onboard(age = 3, name = 'Darcy') {
  const ctx = await boot();
  const { page } = ctx;

  await clickFrac(page, 0.5, 0.638, "Let's start");
  await page.waitForTimeout(2500);

  // name
  await clickFrac(page, 0.5, 0.571, 'name field');
  await page.keyboard.type(name, { delay: 70 });
  await page.waitForTimeout(600);
  await clickFrac(page, 0.5, 0.696, "That's me");
  await page.waitForTimeout(2800);

  // age
  const xy = AGE_XY[age] || AGE_XY[3];
  await clickXY(page, xy[0], xy[1], 'age ' + age);
  await page.waitForTimeout(3500);

  // consent (children <13): scroll, check box, give permission
  if (age < 13) {
    for (let i = 0; i < 8; i++) { await page.mouse.wheel(0, 700); await page.waitForTimeout(600); }
    await clickXY(page, 357, 767, 'consent checkbox');
    await page.waitForTimeout(900);
    await clickXY(page, 207, 842, 'give permission');
    await page.waitForTimeout(4500);
  }

  // "Shape the stories" modal -> Maybe later
  await clickXY(page, 151, 586, 'maybe later');
  await page.waitForTimeout(3000);

  return ctx;
}
