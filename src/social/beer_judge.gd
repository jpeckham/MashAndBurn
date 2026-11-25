extends RefCounted
## Fictional pale-ale rubric: five categories, 20 points each; no ML or remote judge.
func evaluate(s: Dictionary) -> Dictionary:
	var f: Dictionary = s.flaws
	var infection := 1.0 if s.infected else 0.0
	var categories := {
		"aroma": snappedf(clampf(20 - f.dms*8 - f.esters*5 - f.diacetyl*12 - f.acetaldehyde*10,0,20),.1),
		"appearance": snappedf(clampf(14 + s.flocculation*6 - infection*10,0,20),.1),
		"flavor": snappedf(clampf(20 - f.astringency*8 - f.phenolic*8 - f.fusels*10 - f.diacetyl*10 - f.acetaldehyde*10 - infection*15,0,20),.1),
		"mouthfeel": snappedf(clampf(20 - absf(s.co2_volumes-2.4)*7 - f.astringency*6,0,20),.1),
		"style_accuracy": snappedf(clampf(20 - absf(s.ibu-35)*.25 - absf(s.og-1.055)*150 - (1-s.attenuation)*8,0,20),.1)}
	var feedback: Array = []
	var severe: Array = []
	if s.ibu < 25: feedback.append("Low bitterness for the pale-ale target: add hops earlier or increase the charge.")
	if s.ibu > 50: feedback.append("Bitterness dominates: reduce the bittering charge or shorten exposure.")
	if f.astringency > .1 or f.phenolic > .1: feedback.append("Scorched/astringent notes: keep the mash in the 64–72 C range.")
	if f.dms > .1: feedback.append("Cooked vegetable aroma: give the wort a full vigorous boil.")
	if f.fusels > .1 or f.esters > .3: feedback.append("Warm fermentation produced solvent/fruit notes: lower the yeast target temperature.")
	for flaw in ["diacetyl","acetaldehyde"]:
		if f[flaw] >= .6: severe.append(flaw)
		if f[flaw] > .1: feedback.append(("Butter (diacetyl)" if flaw == "diacetyl" else "Green apple (acetaldehyde)") + ": allow more yeast cleanup time.")
	if infection > 0: feedback.append("Infection detected: cool faster and improve fictional sanitation.")
	if s.co2_volumes > 3.5: feedback.append("Overpressure: reduce priming sugar. This batch has a safety latch.")
	elif s.co2_volumes < 1.8: feedback.append("Thin carbonation: adjust priming or regulator pressure for package temperature.")
	if feedback.is_empty(): feedback.append("Balanced fictional pale ale. Stable fermentation and appropriate packaging paid off.")
	var score := 0.0
	for value in categories.values(): score += value
	return {"type":"JudgeResult","version":1,"seq":s.seq,"tick":s.tick,"batch_id":s.batch_id,"categories":categories,"score":snappedf(score,.1),"feedback":feedback,"severe_flaws":severe}
