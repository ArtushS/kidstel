export type ModerationResult = {
  allowed: boolean;
  reason?: string;
};

// NOTE: Keep deterministic rules conservative.
const BANNED_PATTERNS: Array<{ re: RegExp; reason: string }> = [
  { re: /\b(sex|porn|nude|naked|erotic)\b/i, reason: 'sexual content' },
  { re: /\b(suicide|kill\s+myself|self-harm|cut\s+myself)\b/i, reason: 'self-harm' },
  { re: /\b(drugs?|cocaine|heroin|meth|weed|marijuana)\b/i, reason: 'drugs' },
  { re: /\b(gun|knife|stab|shoot|blood|gore)\b/i, reason: 'violence' },
  { re: /\b(hate\s+speech|nazi|kkk)\b/i, reason: 'hate/extremism' },
];

export function moderateText(text: string, maxChars: number): ModerationResult {
  const t = (text ?? '').toString();
  if (t.length > maxChars) {
    return { allowed: false, reason: 'input too long' };
  }
  for (const p of BANNED_PATTERNS) {
    if (p.re.test(t)) return { allowed: false, reason: p.reason };
  }
  return { allowed: true };
}

export const KIDS_POLICY_SYSTEM = `
You are KidsTel, a children's interactive story generator.

Hard rules (must ALWAYS be satisfied):
- Audience: children (ages 3-12).
- No explicit violence, gore, weapons, torture, threats.
- No sexual content.
- No self-harm.
- No drugs or alcohol.
- No hate or discrimination.
- No scary horror themes; keep gentle and reassuring.
- No instructions for wrongdoing.
- Use simple, kind, encouraging language.

Output format MUST be valid JSON and MUST match the provided schema.
`;
