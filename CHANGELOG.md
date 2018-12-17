# Change Log

## [v0.7.2](https://github.com/vibrato/awskeyring/tree/v0.7.2) (2018-12-17)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.7.1...v0.7.2)

**Fixed bugs:**

- Validate that account doesn't already exists. [\#40](https://github.com/vibrato/awskeyring/pull/40) ([tristanmorgan](https://github.com/tristanmorgan))
- Check for COMMAND param to exec. [\#38](https://github.com/vibrato/awskeyring/pull/38) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.7.1](https://github.com/vibrato/awskeyring/tree/v0.7.1) (2018-12-03)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.7.0...v0.7.1)

**Fixed bugs:**

- Trailing LF was being passed to validator [\#37](https://github.com/vibrato/awskeyring/pull/37) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.7.0](https://github.com/vibrato/awskeyring/tree/v0.7.0) (2018-11-26)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.6.0...v0.7.0)

**Implemented enhancements:**

- Validate existing account. [\#35](https://github.com/vibrato/awskeyring/pull/35) ([tristanmorgan](https://github.com/tristanmorgan))
- Swap Highline for Thor::LineEditor [\#34](https://github.com/vibrato/awskeyring/pull/34) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.6.0](https://github.com/vibrato/awskeyring/tree/v0.6.0) (2018-10-18)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.5.3...v0.6.0)

**Fixed bugs:**

- Use a default Region for Rotate. [\#33](https://github.com/vibrato/awskeyring/pull/33) ([tristanmorgan](https://github.com/tristanmorgan))
- Fix JSON time format to use ISO8601. [\#32](https://github.com/vibrato/awskeyring/pull/32) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.5.3](https://github.com/vibrato/awskeyring/tree/v0.5.3) (2018-10-03)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.5.2...v0.5.3)

**Implemented enhancements:**

- Console favourites [\#31](https://github.com/vibrato/awskeyring/pull/31) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.5.2](https://github.com/vibrato/awskeyring/tree/v0.5.2) (2018-09-18)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.5.1...v0.5.2)

**Implemented enhancements:**

- More robust autocomplete. [\#30](https://github.com/vibrato/awskeyring/pull/30) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.5.1](https://github.com/vibrato/awskeyring/tree/v0.5.1) (2018-09-12)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.5.0...v0.5.1)

**Implemented enhancements:**

- Autocomplete flags too. [\#29](https://github.com/vibrato/awskeyring/pull/29) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.5.0](https://github.com/vibrato/awskeyring/tree/v0.5.0) (2018-09-10)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.4.0...v0.5.0)

**Implemented enhancements:**

- Separate update account from add account. [\#28](https://github.com/vibrato/awskeyring/pull/28) ([tristanmorgan](https://github.com/tristanmorgan))

**Merged pull requests:**

- Refactor [\#27](https://github.com/vibrato/awskeyring/pull/27) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.4.0](https://github.com/vibrato/awskeyring/tree/v0.4.0) (2018-08-21)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.3.1...v0.4.0)

**Implemented enhancements:**

- I18n - Internationalisation [\#26](https://github.com/vibrato/awskeyring/pull/26) ([tristanmorgan](https://github.com/tristanmorgan))
- Adds no token flag to skip saved token [\#25](https://github.com/vibrato/awskeyring/pull/25) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.3.1](https://github.com/vibrato/awskeyring/tree/v0.3.1) (2018-07-25)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.3.0...v0.3.1)

**Implemented enhancements:**

- Warn about key-age [\#24](https://github.com/vibrato/awskeyring/pull/24) ([tristanmorgan](https://github.com/tristanmorgan))

**Fixed bugs:**

- Error adding account when region is not specified [\#21](https://github.com/vibrato/awskeyring/issues/21)
- Check more locations for current region. [\#23](https://github.com/vibrato/awskeyring/pull/23) ([tristanmorgan](https://github.com/tristanmorgan))

**Merged pull requests:**

- Set a default region on cred verify. [\#22](https://github.com/vibrato/awskeyring/pull/22) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.3.0](https://github.com/vibrato/awskeyring/tree/v0.3.0) (2018-04-12)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.2.0...v0.3.0)

**Implemented enhancements:**

- Validate tokens upon adding them to the keychain [\#18](https://github.com/vibrato/awskeyring/issues/18)
- Generate a token from IAM User credentials using the GetFederationToken API [\#17](https://github.com/vibrato/awskeyring/issues/17)
- Test creds against AWS API \(optionally\). [\#20](https://github.com/vibrato/awskeyring/pull/20) ([tristanmorgan](https://github.com/tristanmorgan))
- Allow STS get\_session\_token without role [\#19](https://github.com/vibrato/awskeyring/pull/19) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.2.0](https://github.com/vibrato/awskeyring/tree/v0.2.0) (2018-04-05)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.1.1...v0.2.0)

**Implemented enhancements:**

- Add AWS CLI credential\_process compatible JSON output [\#16](https://github.com/vibrato/awskeyring/pull/16) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.1.1](https://github.com/vibrato/awskeyring/tree/v0.1.1) (2018-03-25)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.1.0...v0.1.1)

**Merged pull requests:**

- More coverage with tests. [\#15](https://github.com/vibrato/awskeyring/pull/15) ([tristanmorgan](https://github.com/tristanmorgan))
- Validate MFA code and tweak Autocomplete [\#14](https://github.com/vibrato/awskeyring/pull/14) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.1.0](https://github.com/vibrato/awskeyring/tree/v0.1.0) (2018-03-14)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.0.6...v0.1.0)

**Implemented enhancements:**

- Item refactor [\#13](https://github.com/vibrato/awskeyring/pull/13) ([tristanmorgan](https://github.com/tristanmorgan))
- Aws refactor [\#12](https://github.com/vibrato/awskeyring/pull/12) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.0.6](https://github.com/vibrato/awskeyring/tree/v0.0.6) (2018-03-01)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.0.5...v0.0.6)

**Implemented enhancements:**

- Credential Rotation Feature [\#4](https://github.com/vibrato/awskeyring/issues/4)
- Rotate credentials feature. [\#11](https://github.com/vibrato/awskeyring/pull/11) ([tristanmorgan](https://github.com/tristanmorgan))

**Merged pull requests:**

- Input validation [\#10](https://github.com/vibrato/awskeyring/pull/10) ([tristanmorgan](https://github.com/tristanmorgan))
- Adding a check for incorrect file modes. [\#9](https://github.com/vibrato/awskeyring/pull/9) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.0.5](https://github.com/vibrato/awskeyring/tree/v0.0.5) (2018-02-15)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.0.4...v0.0.5)

**Fixed bugs:**

- Issue on add [\#7](https://github.com/vibrato/awskeyring/issues/7)

**Merged pull requests:**

- fix issue \#7 and add a path to open console. [\#8](https://github.com/vibrato/awskeyring/pull/8) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.0.4](https://github.com/vibrato/awskeyring/tree/v0.0.4) (2018-01-29)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.0.3...v0.0.4)

## [v0.0.3](https://github.com/vibrato/awskeyring/tree/v0.0.3) (2018-01-28)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.0.2...v0.0.3)

**Implemented enhancements:**

- Remove Token feature [\#5](https://github.com/vibrato/awskeyring/issues/5)
- Implement exec command [\#2](https://github.com/vibrato/awskeyring/issues/2)
- Add Remove token feature [\#6](https://github.com/vibrato/awskeyring/pull/6) ([tristanmorgan](https://github.com/tristanmorgan))
- Implement exec feature. [\#3](https://github.com/vibrato/awskeyring/pull/3) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.0.2](https://github.com/vibrato/awskeyring/tree/v0.0.2) (2018-01-18)
[Full Changelog](https://github.com/vibrato/awskeyring/compare/v0.0.1...v0.0.2)

**Merged pull requests:**

- Sledgehammer disable of rubocop metrics. [\#1](https://github.com/vibrato/awskeyring/pull/1) ([tristanmorgan](https://github.com/tristanmorgan))

## [v0.0.1](https://github.com/vibrato/awskeyring/tree/v0.0.1) (2017-12-25)


\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*