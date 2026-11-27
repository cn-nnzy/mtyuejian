# Version assessment profile v1

This profile evaluates version evidence in supplied OSV records. It does not
decide exploitability, runtime platform applicability, database completeness,
authenticity of an advisory, or the safety of an installed application.

## Identity and outcomes

Package identity is the exact pair `(ecosystem, name)`. An inventory ID labels an
installation; it is unique within that inventory. PURLs, aliases, case folding,
Unicode normalization and package-manager-specific name normalization do not
establish identity in this release.

For each relevant package/advisory pair, the result is:

- `affected`: a supported range or reliable exact version enumeration matches.
- `not_matched`: the supplied record's supported version evidence does not match.
- `undetermined`: no known positive, with some unsupported or missing evidence.
- `withdrawn`: the relevant record has a validated withdrawn timestamp. It remains
  visible and requires review; it does not erase other records' positive matches.

An installation without any relevant record gets `no_advisory` and requires
review. These names describe record evaluation, not global vulnerability status.
Counts count package/advisory decisions, not unique CVEs. Aliases are metadata,
never an instruction to merge records or suppress a finding.

An active affected entry without package identity appears in `unscoped_entries`
and prevents exit 0. The library does not assume that an unscoped Git record is
unrelated to the inventory. A known positive takes exit-code precedence (1) over
incomplete evidence (3), while the report retains both.

## Range semantics

SEMVER follows SemVer 2.0.0 ASCII precedence, including numeric/non-numeric
prerelease identifiers and prerelease list length. Major, minor, patch and
numeric prerelease identifiers are compared as digit strings without overflow.
Build metadata is validated but excluded from ordering. No leading `v`, missing
version components, whitespace, Unicode digits or numeric leading zeros are
coerced into valid versions.

Events are sorted for evaluation while retaining their source indices. An
introduction starts an inclusive interval; `fixed` closes it exclusively;
`last_affected` closes it inclusively. A single-version interval closed by
`last_affected` is supported. Repeated introductions before closure, closing
without introduction, and equal-precedence ambiguous transitions are rejected.
This strict input profile deliberately rejects redundant transition encodings
rather than choosing an ordering that may change their meaning.

An open interval has no upper endpoint. `introduced: "0"` denotes negative
infinity and is not the SemVer version `0.0.0`. Multiple intervals and ranges
form a union. If limits are present, the query must precede at least one of them;
`limit: "*"` admits every version. Limits are separate from fix transitions.

`versions` uses exact string equality. Its positive matches are unioned with
range matches. Entries mixing GIT and package-version enumeration cannot use
that enumeration for a positive conclusion, because those strings may be tags.
Supported SEMVER ranges in the same entry can still establish a positive match.
Unsupported ranges are retained and mark the decision incomplete even then.

The difference between `last_affected`, `limit` and a confirmed `fixed` boundary
remains visible through original event indices and the retained source. A
`not_matched` result beyond a last-known boundary is not proof of a fix.

## Input validation and preservation

The private JSON reader enforces grammar, unique decoded object keys, bounded
nesting and well-formed Unicode. Numbers are retained as tokens. In particular,
unknown metadata such as a large integer or exponent cannot be rounded through
Double before the source is saved.

OSV IDs and required modified timestamps are checked. Schema version defaults
to 1.0.0 and must fall between 1.0.0 and 1.9.2 without build/prerelease suffixes.
Timestamps accept uppercase T/Z or numeric offsets, up to nine fractional digits,
valid calendar dates and seconds 0–59. Leap seconds and year zero are rejected.
Published/withdrawn timestamps, when present, use the same profile.

Unknown top-level, affected-entry and package metadata remain in the exact
original source. The evaluator does not apply ecosystem-specific conditions.
Unknown SEMVER event or range-object fields are rejected because their meaning
could change range evaluation. Unsupported range types are retained without
pretending that their event payload has been semantically validated. This
reader is not a full validator for unused OSV fields such as severity or credits.

Inventory and snapshot envelopes use closed v1 formats. Unknown envelope fields
are rejected. Duplicate advisory IDs are rejected even if their text is equal;
the caller must select a revision explicitly. Duplicate source records are
never resolved by timestamp guessing or a last-writer rule.

Snapshot serialization stores each complete original advisory as a JSON string
with its origin label. Re-reading validates those sources again. It preserves
all source characters, including whitespace and unsupported metadata. Reports
are derived views and do not contain the complete source; retain the snapshot
when reproducibility is required. Origin labels and timestamps are caller data,
not verified provenance. There is no signature or tamper-detection claim.

## Budgets

| Resource | Limit |
|---|---:|
| OSV/inventory input | 1,048,576 UTF-16 code units |
| Snapshot envelope | 2,097,152 UTF-16 code units |
| JSON nesting / values | 48 / 100,000 |
| Cumulative constructed JSON Pointer text | 16,777,216 UTF-16 units |
| Nonblank identity/source strings | 4,096 code units |
| SemVer string | 256 code units |
| Inventory packages | 1–1,024 |
| Snapshot documents / total source and origin labels | 1–64 / 262,144 code units |
| Package/document pairs in an assessment | 16,384 |
| Affected entries per document | 256 |
| Ranges per affected entry | 128 |
| Events per range | 4,096 |
| Enumerated versions per affected entry | 8,192 |
| Aliases per document | 128 |
| CLI file byte size | 8 MiB |

All JSON readers enforce the cumulative pointer-work budget, even without source
indexing. This stops small documents with long ancestor keys and repeated child
values from repeatedly constructing very large paths. The check runs before
allocating each child pointer and raises `json-work-limit`; it does not truncate
metadata. Reads within the budget preserve the same values and source text.

The CLI requires strict UTF-8 JSON without a BOM and reads bounded chunks. No
input file is rewritten. All input failures return structured diagnostics and
exit 2 before a partial assessment is printed. Successful library objects are
immutable; returned JSON and outcome arrays do not mutate their backing state.

Direct library calls enforce the same Unicode boundary: package fields and
origin labels reject unpaired UTF-16 surrogates with `invalid-unicode` at the
field pointer, before JSON or UTF-8 encoding can replace data. Valid non-BMP
characters are retained without normalization. `inventory_json` also checks the
complete encoded document, including JSON escaping, against the reader's
1,048,576-unit limit. Individually valid fields can exceed that aggregate budget;
such inventories raise `document-limit` rather than producing an unreadable
export. The same check applies before assessment. Split large inputs into
bounded assessments and review every partition; a result covers only its own
supplied inventory and snapshot.
