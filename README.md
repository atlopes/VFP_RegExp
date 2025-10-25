# VFP_RegExp

VFP_RegExp is a class that interfaces with the PCRE Regular Expression engine. It is modelled after the VBScript.RegExp component and aims to replace it.

VFP programmers have been relying on the availability of VBScript.RegExp to address their need for a Regular Expression engine.

Besides lacking more recent and advanced features, Microsoft's announcement of VBScript's deprecation increased the necessity of an alternative.

VFP_RegExp relies on the PCRE2 library as its engine and exposes the same properties and methods as the VBScript engine. Thus, it facilitates migration from the current code while gaining access to many advanced capabilities of PCRE.

Other main goal of VFP_RegExp is to incorporate other PCRE features (like identifying the matched value of named groups, for instance) without compromising compatibility with the VBScript object.

Information on the VBScript.RegExp Object:
- [@ Microsoft](https://learn.microsoft.com/en-us/previous-versions/yab2dx62(v=vs.85))
- [@ Regular Expressions Info](https://www.regular-expressions.info/vbscript.html)

Information on PCRE and PCRE2 library:
- [PCRE2 Project](https://pcre2project.github.io/pcre2/)
- [Documentation](https://pcre2project.github.io/pcre2/doc/)
- [@ Regular Expressions Info](https://www.regular-expressions.info/pcre2.html)

## Properties

Properties marked as `VBS` come from the VBScript object; those marked as `PCRE` are defined by the `PCRE2` library; those marked as `VFP` are determined by the VFP_RegExp class and have some informational or functional value, as described in the table below.

Refer to the respective documentation for those marked as `VBS` or `PCRE`.

|Property|Source|Type|Notes|
|---|---|---|---|
|DotAll|PCRE|L| |
|Extended|PCRE|L| |
|Global|VBS|L| |
|Groups|VFP|N|The number of capturing groups in a regular expression.|
|IgnoreCase|VBS|L| |
|MatchCollectionBaseClass|VFP|C|The base class of the RegExp collections, either "Custom" or "Collection"|
|Multiline|VBS|L| |
|NamedMatches|VFP|O|A collection of matches captured by named groups.|
|NormalizeCRLF|VFP|L|Normalize newlines in a subject string changing them from LF or CR to CR+LF, before matching.|
|RegExpEngine|VFP|C|Name and version of the PCRE2 library.|
|Pattern|VBS|C| |
|RegExpError|VFP|N|Error code found during an PCRE2 operation (negative numbers), or during VFP execution (positive numbers).|
|RegExpErrorLocation|VFP|C|Where in the pattern a syntactic error was located, or where in the code an execution error occurred.|
|RegExpErrorMessage|VFP|C|A message corresponding to the error code.|
|SafetyValve|VFP|N|Set to something greater than zero to prevent infinite or large loops in the matching process.|
|Ungreedy|PCRE|L| |
|Version|VFP|N|The version of the class.|

## Methods

The class exposes the three methods available in VBScript.RegExp (`Execute()`, `Test()`, and `Replace()`), and offers additional ones to deal with extensions to the VBScript model.

### VBScript-like methods

#### `.Execute(SubjectString AS String) AS RegExp_MatchCollection`

Matches a subject string against the pattern and returns a collection of matches of the `RegExp_Match` type, organized under a `RegExp_MatchCollection` object.

An application can find the number of matches in the `RegExp_MatchCollection.Count` property, and access an individual match by addressing it through `RegExp_MatchCollection.Item(<0 to .Count - 1>)`.

Every `RegExp_Match` holds a `RegExp_SubMatchesCollection` which, in turn, holds information on every `RegExp_SubMatch` of the match, corresponding to the capturing groups of the regular expression.

The properties and methods of these objects are the same as those found in the corresponding objects in VBScript.

In case there are named groups in the pattern string, the `NamedMatches` collection addresses the set of those named groups.

For instance, executing a subject string `"3.14"` against the pattern `"^(?<integer>\d+(?<fractional>\.[\d]+)?)$"` will set a two-member collection, of which `.NamedMatches("integer")` returns `"3"`, `.NamedMatches("fractional")` returns `".14"`, `.NamedMatches.Count` returns `2`, and `.NamedMatches.GetKey(1)` returns `"integer"`.

#### `.Replace(SubjectString AS String, Replacement AS String) AS String`

Replaces a subject string with a replacement string pattern, which may hold references to the capturing groups in the regular expression (as supported by the VBScript object).

For instance, if the regular expression has two sequential capturing groups, the replacement string `"$2$1"` swaps their positions, and the replacement string `"$1"` removes the contents of the second group.

The method can also deal with named groups, referenced as `$<name>`.

#### `.Test(SubjectString AS String) AS Logical`

Tests a subject string against the pattern and returns `.T.` if it matches, in whole or partially, or `.F.`, otherwise.

### Other methods

#### `.Validate() AS Logical`

Validates the pattern string.

Returns `.T.` if the pattern is valid, `.F.` otherwise.

`.RegExpError*` properties may be used to get additional information in case of error.

## Using

To put the class in scope, run the procedure program:

```foxpro
DO regexvfp_pcre
```

The class is used in the same way that a VSCript.RegExp object is instantiated and used:
```foxpro
m.RegExp = CREATEOBJECT("VFP_RegExp")  && instead of "VBScript.RegExp"
m.RegExp.Pattern = "^(\d+(\.[\d]+)?)$"
? m.RegExp.Test("78.230")
```

Since method chaining is not generally possible with VFP native objects, it's necessary to identify each object of the chain.

Therefore, this construction that would possible using a VBScript.RegExp object
```foxpro
? m.RegExp.Execute("78.230").Item(0).SubMatches.Count
```
must be rewritten, for a VFP_RegExp object, as something like
```foxpro
m.Matches = m.RegExp.Execute("78.230")
m.Match = m.Matches.Item(0)
? m.Match.SubMatches.Count
```
or, if not using variables, as
```foxpro
WITH CREATEOBJECT("VFP_RegExp") AS VFP_RegExp
	.Pattern = "^(\d+(\.[\d]+)?)$"
	WITH .Execute("78.230") AS RegExp_MatchCollection
		WITH .Item(0) AS RegExp_Match
			? .SubMatches.Count
		ENDWITH
	ENDWITH
ENDWITH
```

It's possible to base the RegExp collection classes (`RegExp_MatchCollection` and `RegExp_SubMatchCollection`) on the VFP `Collection` object instead of `Custom`. This will lead to three differences in how the results are treated: references to the member of the collections are 1-based; the `Item()` method of `RegExp_MatchCollection` can be chained; and the collections can be iterated through their members.

```foxpro
LOCAL RX AS VFP_RegExp
LOCAL Matches AS RegExp_MatchCollection	&& or RegExp_MatchCollection2

m.RX = CREATEOBJECT("VFP_RegExp")

m.RX.MatchCollectionBaseClass = "Collection"
m.RX.Global = .T.

m.RX.Pattern = "([A-Z])\w+"

m.Matches = m.RX.Execute("the quick brown Fox jumps over a lazy Dog")

FOR EACH m.Match AS RegExp_Match IN m.Matches

	? m.Match.Value
	? m.Match.SubMatches.Item(1)

ENDFOR
```

Check also the demo folder for examples on using the class.

## Dependencies

The class requires a PCRE2 8-bit DLL (where 8-bit refers to the size of a character).

For convenience, an already-built DLL is available in the source folder, but you can use any other that may be present in your system. Before use, read the accompanying license document.

Distributed PCRE2 version: 10.45.

## Licensing and acknowledgments

The VFP class is [unlicensed](UNLICENSE.md "Unlicense").

**PCRE2 Basic Library Functions** by Philip Hazel, copyright (c) 1997-2025 University of Cambridge, distributed under a [BSD license](PCRE2_LICENCE.md "BSD License"), with exceptions.

DLL built using the configuration / VS solution in [pcre2-win-build](https://github.com/kiyolee/pcre2-win-build "PCRE2 Windows Build"), by Kelvin Lee.

## Status

In development.
