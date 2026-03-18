# Feelings Wheel Taxonomy Audit Report

Generated: 2026-01-30


## Summary Statistics

- **Core Emotions:** 7
- **Secondary Feelings:** 40
- **Tertiary Feelings:** 98
- **Total Unique Labels:** 133

## Structure by Core Emotion

| Core | Secondary Count | Tertiary Count | Balance Score |
|------|-----------------|----------------|---------------|
| Happy | 9 | 18 | 6.0/10 |
| Surprised | 4 | 8 | 9.0/10 |
| Bad | 4 | 8 | 9.0/10 |
| Fearful | 6 | 12 | 9.0/10 |
| Sad | 7 | 28 | 5.0/10 |
| Disgusted | 2 | 8 | 4.0/10 |
| Angry | 8 | 16 | 7.0/10 |

## Issues Identified

- IMBALANCE: Disgusted has only 2 secondaries (target: 4+)
- DUPLICATE: 'Sensitive' appears in: Happy/Trusting, Sad/Vulnerable
- DUPLICATE: 'Overwhelmed' appears in: Bad/Stressed, Fearful/Anxious, Sad/Despair
- DUPLICATE: 'Helpless' appears in: Fearful/Scared, Sad/Despair
- DUPLICATE: 'Nervous' appears in: Fearful/Threatened, Sad/Worried
- DUPLICATE: 'Exposed' appears in: Fearful/Threatened, Sad/Vulnerable
- DUPLICATE: 'Numb' appears in: Sad/Depressed, Angry/Distant
- DUPLICATE: 'Uneasy' appears in: Sad/Worried, Disgusted/Uncomfortable

## Duplicate Emotions (Cross-Branch)

These emotions appear under multiple parents:

- **Sensitive**: Happy/Trusting, Sad/Vulnerable
- **Overwhelmed**: Bad/Stressed, Fearful/Anxious, Sad/Despair
- **Helpless**: Fearful/Scared, Sad/Despair
- **Nervous**: Fearful/Threatened, Sad/Worried
- **Exposed**: Fearful/Threatened, Sad/Vulnerable
- **Numb**: Sad/Depressed, Angry/Distant
- **Uneasy**: Sad/Worried, Disgusted/Uncomfortable

## Asset Coverage

- **Assets Found:** 120
- **Assets Missing:** 25

### Missing Assets

- hopeless.png (Hopeless)
- sorry.png (Sorry)
- regretful.png (Regretful)
- responsible.png (Responsible)
- drained.png (Drained)
- low_energy.png (Low energy)
- lonely.png (Lonely)
- left_out.png (Left out)
- forgotten.png (Forgotten)
- alone.png (Alone)
- isolated.png (Isolated)
- hurt.png (Hurt)
- upset.png (Upset)
- heartbroken.png (Heartbroken)
- uneasy.png (Uneasy)
- grossed_out.png (Grossed Out)
- yucky.png (Yucky)
- icky.png (Icky)
- nasty.png (Nasty)
- eww.png (Eww)
- uncomfortable.png (Uncomfortable)
- awkward.png (Awkward)
- uneasy.png (Uneasy)
- weird.png (Weird)
- off.png (Off)

## Recommendations

1. **Disgusted** core has only 2 secondary feelings - consider if this is intentional for a children's app
2. **Sad** branch has several 4-tertiary groups which may crowd the UI
3. Several duplicate tertiary emotions exist - ensure this is intentional for multi-path navigation
4. Create missing face assets for complete visual coverage