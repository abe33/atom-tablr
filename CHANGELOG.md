<a name="v1.8.3"></a>
# v1.8.3 (2017-03-31)

## :bug: Bug Fixes

- Fix Atom crashing when opening several csv at the same time ([126feac5](https://github.com/abe33/atom-tablr/commit/126feac53277aa756677f2f69d364335f932c76a), [#86](https://github.com/abe33/atom-tablr/issues/86))
- Fix access to model once destroyed ([0c8e1089](https://github.com/abe33/atom-tablr/commit/0c8e10897e7b078476c220d6d812e30690ee7959), [#87](https://github.com/abe33/atom-tablr/issues/87))

<a name="v1.8.2"></a>
# v1.8.2 (2017-03-31)

## :bug: Bug Fixes

- Fix access to header for empty file ([69a2558e](https://github.com/abe33/atom-tablr/commit/69a2558e11ec73e6dfc457b99b1ff5203e881881), [#85](https://github.com/abe33/atom-tablr/issues/85))

<a name="v1.8.1"></a>
# v1.8.1 (2017-01-09)

## :bug: Bug Fixes

- Serialize undefined columns as nil so that can be properly restored ([f03b941d](https://github.com/abe33/atom-tablr/commit/f03b941d1decce1674b7cb6b3a772a8c819f4cd8))
- Fix Identifiable mixin ([3e1f1fa0](https://github.com/abe33/atom-tablr/commit/3e1f1fa032cd1624fac18d53a0f862f47783bcd4))
- Fix missing semi-colon in style declaration ([a38317b0](https://github.com/abe33/atom-tablr/commit/a38317b027457561af3e41e158881f0d4eaaf5b0))
- Fix allow amending a commit during a batch transaction ([b12444d1](https://github.com/abe33/atom-tablr/commit/b12444d10397c7338045f255e3f57f32d9a162c2))
- Fix CSV settings scroll when window make the row breaks ([8495e3a9](https://github.com/abe33/atom-tablr/commit/8495e3a9e2c1126b8b467e561373ed871ab9950c))

<a name="v1.8.0"></a>
# v1.8.0 (2016-11-29)

## :sparkles: Features

- Add an option to specify the editor grammar for a column ([ef43eedb](https://github.com/abe33/atom-tablr/commit/ef43eedbf33b080e59d02d997a57db0933c1b538))

## :bug: Bug Fixes

- Fix keyboard events not registered ([5dd9a90e](https://github.com/abe33/atom-tablr/commit/5dd9a90ec8b8b243e777b6b5f82aed67cf2a78c2))

<a name="v1.7.0"></a>
# v1.7.0 (2016-11-28)

## :sparkles: Features

- Expose CSVEditor in service ([18e40d49](https://github.com/abe33/atom-tablr/commit/18e40d49a0ad7424cdb6872b9a6a1e5214fbc9d3))

## :bug: Bug Fixes

- Add background on text-editor ([e1ef96cc](https://github.com/abe33/atom-tablr/commit/e1ef96ccbeb8e146ff6bb809ed7b460f99e080fb), [#74](https://github.com/abe33/atom-tablr/issues/74))


<a name="v1.6.2"></a>
# v1.6.2 (2016-11-21)

## :bug: Bug Fixes

- Fix error raised when closing a cell editor ([2831be2d](https://github.com/abe33/atom-tablr/commit/2831be2d34228f4367ab12d3a2b4726214897ccd))
- Fix typo in configSchema ([b70eb6e8](https://github.com/abe33/atom-tablr/commit/b70eb6e88ebf250f31fc158128e1d3e48b860dd4))

<a name="v1.6.1"></a>
# v1.6.1 (2016-10-24)

- :fire: remaining logs

<a name="v1.6.0"></a>
# v1.6.0 (2016-10-24)

## :arrow_up: Dependencies Update

- Bump atom engine version since the new version no longer rely on shadow DOM ([2661ac01](https://github.com/abe33/atom-tablr/commit/2661ac01bc97fbcab35119ed134c8c727b8198cb))

<a name="v1.5.5"></a>
# v1.5.5 (2016-10-04)

## :bug: Bug Fixes

- Fix issues related to incoming coffee script version bump in Atom ([05581970](https://github.com/abe33/atom-tablr/commit/0558197003e60822cc7f26f8eab5cc79211c335d), [#70](https://github.com/abe33/atom-tablr/issues/70))

<a name="v1.5.4"></a>
# v1.5.4 (2016-09-30)

## :bug: Bug Fixes

- Remove import of buttons.less ([7c424eac](https://github.com/abe33/atom-tablr/commit/7c424eacba67982f7285ce716fc434439d713cd2), [#69](https://github.com/abe33/atom-tablr/issues/69))

<a name="v1.5.3"></a>
# v1.5.3 (2016-09-12)

## :bug: Bug Fixes

- Fix default setting not always applied on file open ([7a0b9d35](https://github.com/abe33/atom-tablr/commit/7a0b9d3521ea09b58fe3e7a149e49808c1bace0e), [#67](https://github.com/abe33/atom-tablr/issues/67))

<a name="v1.5.2"></a>
# v1.5.2 (2016-09-08)

## :bug: Bug Fixes

- Fix pending state on CSV editor when confirming opening a table editor ([24becf4f](https://github.com/abe33/atom-tablr/commit/24becf4fe15e7b4b1fb381a37552d61b86d67c8a), [#65](https://github.com/abe33/atom-tablr/issues/65))
- Fix error in displayEllipsis if there's no table editor ([d97add73](https://github.com/abe33/atom-tablr/commit/d97add732d6ef2f99261f774cdbf7b6323461884), [#63](https://github.com/abe33/atom-tablr/issues/63))

<a name="v1.5.1"></a>
# v1.5.1 (2016-09-02)

## :bug: Bug Fixes

- Fix issue if tablr.supportedCsvExtensions gets null ([2c673f2c](https://github.com/abe33/atom-tablr/commit/2c673f2cef48bb88eeb86062ceb7b68ae4fb84f0), [#64](https://github.com/abe33/atom-tablr/issues/64))

<a name="v1.5.0"></a>
# v1.5.0 (2016-08-26)

## :racehorse: Performances

- Move deserializers and view providers in package.json ([d4ab79c4](https://github.com/abe33/atom-tablr/commit/d4ab79c40551d22c0b422f33b353d516150eadb2))

## :arrow_up: Dependencies Update

- Bump engine version to >= 1.7.0 ([62c18329](https://github.com/abe33/atom-tablr/commit/62c18329e27f443ebac0427f33462f49e708efb9))

<a name="v1.4.1"></a>
# v1.4.1 (2016-08-25)

## :racehorse: Performances

- Implement a deserialize placeholder for faster startup ([ba2464a4](https://github.com/abe33/atom-tablr/commit/ba2464a4441e3dd64148afb8db1eefb5308f5ff3))

<a name="v1.4.0"></a>
# v1.4.0 (2016-08-23)

## :sparkles: Features

- Add a row when tabbing on the last cell of a table ([c09ba8f9](https://github.com/abe33/atom-tablr/commit/c09ba8f9afe1d8c703e8c10bb50d98c088567bf5), [#62](https://github.com/abe33/atom-tablr/issues/62))

<a name="v1.3.2"></a>
# v1.3.2 (2016-07-06)

## :bug: Bug Fixes

- Fix text editor going past the limit of the pane ([1d02499c](https://github.com/abe33/atom-tablr/commit/1d02499c493605cb6af66fc40862b2d23ff1d02c), [#59](https://github.com/abe33/atom-tablr/issues/59))
- Ensure there's a column and a row when starting an edit ([cb6dc4c3](https://github.com/abe33/atom-tablr/commit/cb6dc4c30552780a09f6c1d53bbcd2aaf9a7d4b4), [#53](https://github.com/abe33/atom-tablr/issues/53))
- Fix inability to save after editing an empty CSV ([abb38230](https://github.com/abe33/atom-tablr/commit/abb38230a93bbf26724f2b75b380b9d907676923), [#58](https://github.com/abe33/atom-tablr/issues/58))
- Fix package defaults not used unless a setting is changed in the form ([0ce23053](https://github.com/abe33/atom-tablr/commit/0ce230535e12ad90c8c464ca54f7b687eceda114), [#57](https://github.com/abe33/atom-tablr/issues/57), [#60](https://github.com/abe33/atom-tablr/issues/60))

<a name="v1.3.1"></a>
# v1.3.1 (2016-05-09)

Remove console log.

<a name="v1.3.0"></a>
# v1.3.0 (2016-05-09)

## :sparkles: Features

- Add disable preview options ([5980fbac](https://github.com/abe33/atom-tablr/commit/5980fbac9c91f624c8c61fd74792fc8f9d9804eb))

## :bug: Bug Fixes

- Fix issue with file name with CSV in it ([afd50964](https://github.com/abe33/atom-tablr/commit/afd50964041e20a8a5cb68532bf1b0595d9795b7), [#45](https://github.com/abe33/atom-tablr/issues/45))
- Fix errors on inconsistent columns count ([6fc2bba1](https://github.com/abe33/atom-tablr/commit/6fc2bba1ad96eae688682f1ba1a240766992cf4b), [#48](https://github.com/abe33/atom-tablr/issues/48))

<a name="v1.2.3"></a>
# v1.2.3 (2016-04-28)

## :bug: Bug Fixes

- Fix uncaught exception when previewing a CSV ([dbe569d3](https://github.com/abe33/atom-tablr/commit/dbe569d3ab512436f12c020e9603ce6f86585326), [#41](https://github.com/abe33/atom-tablr/issues/41))

<a name="v1.2.2"></a>
# v1.2.2 (2016-04-14)

## :bug: Bug Fixes

- Remove pathwatcher and create stream from iconv instead ([c749e29e](https://github.com/abe33/atom-tablr/commit/c749e29e65891b51353c3fb9a0f81b51e21562b0), [#40](https://github.com/abe33/atom-tablr/issues/40))

<a name="v1.2.1"></a>
# v1.2.1 (2016-04-14)

## :bug: Bug Fixes

- Add human readable file size in progress ([0e4b8eab](https://github.com/abe33/atom-tablr/commit/0e4b8eab8e95be529f8d98f1683c29bbc9c125f7))
- Fix missing progress view on deserialization ([145ba62f](https://github.com/abe33/atom-tablr/commit/145ba62f0edb3dceae4fab931fa9930d49d2408d))

<a name="v1.2.0"></a>
# v1.2.0 (2016-04-13)

## :sparkles: Features

- Add new config in CSV specs ([edb7a6e2](https://github.com/abe33/atom-tablr/commit/edb7a6e24204d79f1e6439be03f63a19ad1f4fd1))
- Add a setting for the table creation batch size ([b1420d85](https://github.com/abe33/atom-tablr/commit/b1420d85cec9374a0a679958960153d39983647d))
- Add the row number in preview ([3fe04333](https://github.com/abe33/atom-tablr/commit/3fe0433348156656fb2afee0a1ee8dd201fb934c))
- Add setting for maximum row count in preview ([37f29faa](https://github.com/abe33/atom-tablr/commit/37f29faa94b9ebd710e98166e188dbaee905a003), [#26](https://github.com/abe33/atom-tablr/issues/26))
- Add a loading indicator when opening files ([bf29db1e](https://github.com/abe33/atom-tablr/commit/bf29db1e805d264d424f5f01aa8933c264c6be58))

## :racehorse: Performances

- Speed up table cache content generation through JSON serialization ([c407f8c0](https://github.com/abe33/atom-tablr/commit/c407f8c0f4172da48bae5de1d7b4ad3106800b2f))
- Speed up screen rows update by removing calls to indexOf ([a2f3e08b](https://github.com/abe33/atom-tablr/commit/a2f3e08b2899d45a49a71bb0400c267baa5296ea))

<a name="v1.1.2"></a>
# v1.1.2 (2016-04-11)

## :bug: Bug Fixes

- Fix infinite loop when previewing empty CSV ([f8ec8e3c](https://github.com/abe33/atom-tablr/commit/f8ec8e3cc8bb917f166a879093ba2397eb42ee46), [#38](https://github.com/abe33/atom-tablr/issues/38))

<a name="v1.1.1"></a>
# v1.1.1 (2016-04-01)

## :bug: Bug Fixes

- Fix preview of css with incomplete rows ([0b47c916](https://github.com/abe33/atom-tablr/commit/0b47c916e345c42f6e46bd1f2704e5eb729e2636))

<a name="v1.1.0"></a>
# v1.1.0 (2016-03-31)

## :sparkles: Features

- Add uppercase version of csv and tsv extensions ([1f8011ed](https://github.com/abe33/atom-tablr/commit/1f8011ed33cbfc83c9650c8110478b05aa1ffb24), [#29](https://github.com/abe33/atom-tablr/issues/29))

## :bug: Bug Fixes

- Fix using only the first row to deduce the column count ([7691a4ab](https://github.com/abe33/atom-tablr/commit/7691a4aba970b3c29d445fe67a1c875fd999c325), [#35](https://github.com/abe33/atom-tablr/issues/35))
- Remove ellipsis hint in cells ([7464c737](https://github.com/abe33/atom-tablr/commit/7464c7375a399efa613f53712f0acfe0aed30f63), [#33](https://github.com/abe33/atom-tablr/issues/33))
- Fixing row/column add/delete shortcuts to reflect `table-edit.json` ([0c8322fd](https://github.com/abe33/atom-tablr/commit/0c8322fd085c75062524febb48bd33d47a1c46ea))

<a name="v01.0.2"></a>
# v01.0.2 (2016-02-04)

## :bug: Bug Fixes

- Fix issue with tab delimited files ([5826cd11](https://github.com/abe33/atom-tablr/commit/5826cd11007fd7b9d68876f8e8a37c14d497bf6b), [#30](https://github.com/abe33/atom-tablr/issues/30))

<a name="v01.0.1"></a>
# v01.0.1 (2016-02-04)

## :bug: Bug Fixes

- :fire: remaining logs ([d3fa1b45](https://github.com/abe33/atom-tablr/commit/d3fa1b45670f64d6923e8541de1a3b19155418a6))

<a name="v1.0.0"></a>
# v1.0.0 (2016-02-03)

## :sparkles: Features

- Add global default settings for remaining CSV fields ([9fc64351](https://github.com/abe33/atom-tablr/commit/9fc64351f52d95eb42a7167273dce4c89294a9b1))
- Implement using default CSV config from table settings ([3ace76c4](https://github.com/abe33/atom-tablr/commit/3ace76c4a1a59da630a2a41723ff0db6f7a4dc16), [#28](https://github.com/abe33/atom-tablr/issues/28))
- Add description and proper label to all the settings ([702cd764](https://github.com/abe33/atom-tablr/commit/702cd764f9593df9794f48d6c41171c9af073138))

## Breaking Changes

- due to [3f5505ba](https://github.com/abe33/atom-tablr/commit/3f5505ba56033945e34b0af853ed78b0c82d5a3c), since the settings paths have changed most users will have to reconfigure the package.

<a name="v0.10.0"></a>
# v0.10.0 (2016-01-16)

## :sparkles: Features

- Add a none option to the comment field ([1f9e7e18](https://github.com/abe33/atom-tablr/commit/1f9e7e1894e5590c1fc44c0b02d3168cd132e6c8))
- Implement columns swapping and moving ([5a0c3db4](https://github.com/abe33/atom-tablr/commit/5a0c3db49a1fa53ef3772b16e4402d6e0a16a932), [#24](https://github.com/abe33/atom-tablr/issues/24))
- Add clear-cdv-choice and clear-cdv-layout commands ([8f923539](https://github.com/abe33/atom-tablr/commit/8f923539a2fd972d216cf2d5d280340b8b3dc364))  <br>They allow to remove only the specified stored data without affecting
  the other data
- Implement saving CSV with the specified encoding ([225a12a2](https://github.com/abe33/atom-tablr/commit/225a12a2064f3c8ac53581badaa5faac783092d8))
- Implement encoding support in preview ([e5bba7b1](https://github.com/abe33/atom-tablr/commit/e5bba7b18fe61ac2f7908001b06d0e2be6496a87))
- Add a select to chose encoding in CSV form ([005e8aa6](https://github.com/abe33/atom-tablr/commit/005e8aa68dfd5e06e166dc5494a7dee5be099dcb))

<a name="v0.9.1"></a>
# v0.9.1 (2016-01-05)

## :bug: Bug Fixes

- Fix change event never emitted by the CSV form ([eeec6637](https://github.com/abe33/atom-tablr/commit/eeec6637418c3bc6832cd22736bffc744c441ad9))
- Fix changing mini text editor value target the wrong radio group ([65a68800](https://github.com/abe33/atom-tablr/commit/65a688003678dae968bdac2a27e1fff1b592ebea))

## :arrow_up: Dependencies Update

- Bump atom-utils version ([6ed3f38e](https://github.com/abe33/atom-tablr/commit/6ed3f38ef3f946f74c01a175730770b2d45d1e4a))

<a name="v0.9.0"></a>
# v0.9.0 (2015-12-02)

## :sparkles: Features

- Add command to clear stored data ([696e3c7c](https://github.com/abe33/atom-tablr/commit/696e3c7ca8d9ac8e6eb07b53e47feb236667be9e), [#21](https://github.com/abe33/atom-tablr/issues/21))
- Add context menu to fit columns and rows to content ([c286c22e](https://github.com/abe33/atom-tablr/commit/c286c22e2bbd707603380a19b9804d4f48bb4733), [#20](https://github.com/abe33/atom-tablr/issues/20))

## :bug: Bug Fixes

- Prevent display of column related context menu when in the gutter ([0953463f](https://github.com/abe33/atom-tablr/commit/0953463f38ed7dc47589f4449fab11dd577d6a01), [#19](https://github.com/abe33/atom-tablr/issues/19))

<a name="v0.8.1"></a>
# v0.8.1 (2015-11-27)

## :bug: Bug Fixes

- Fix modified state subscriptions not changed when the editor is changed ([8b38aac9](https://github.com/abe33/atom-tablr/commit/8b38aac99a4269452e841d17dd3e4f23879b2f63))
- Fix file change event make editor partially unusable after save ([9c533b41](https://github.com/abe33/atom-tablr/commit/9c533b4141b8551efa3d730a0b0ef0dd422e8c0b))

<a name="v0.8.0"></a>
# v0.8.0 (2015-11-26)

## :sparkles: Features

- Implement applying sort to the table for save ([28b03dcc](https://github.com/abe33/atom-tablr/commit/28b03dccb2c09f51241cc174e73968bead3b749d), [#14](https://github.com/abe33/atom-tablr/issues/14))
- Implement fit column to content action in header cell ([3d725da1](https://github.com/abe33/atom-tablr/commit/3d725da1c5bf2f7a4c71d1a372ca8be8ed25c482), [#17](https://github.com/abe33/atom-tablr/issues/17))
- Add buttons and new styles for header cells actions ([8dc93993](https://github.com/abe33/atom-tablr/commit/8dc939936aa07690cf7a1d1a1eb1550c7145c99e))
- Implement commands to fit the column and row at cursor to its content size ([847c412d](https://github.com/abe33/atom-tablr/commit/847c412d2538654c001743f30c772171f9700b99))
- Add methods to measure rows height and columns width ([a0ce6de3](https://github.com/abe33/atom-tablr/commit/a0ce6de3e3e37f209ec5ae7b37a75016db3c89a1))

## :bug: Bug Fixes

- Give focus back to the text editor when clicking on it when editing a column ([19091af3](https://github.com/abe33/atom-tablr/commit/19091af3d7c6ad5cb454a5b7d59b062d9d5d42de))

<a name="v0.7.1"></a>
# v0.7.1 (2015-11-24)

## :bug: Bug Fixes

- Fix rename columns with no name ([9682095b](https://github.com/abe33/atom-tablr/commit/9682095b99f1de3e87c5165070c11e3011b21d1a), [#16](https://github.com/abe33/atom-tablr/issues/16))
- Fix layout not serialized if an open editor was not modified ([80327b70](https://github.com/abe33/atom-tablr/commit/80327b704742faa590b544b9f30396a85ffc8ccd))

<a name="v0.7.0"></a>
# v0.7.0 (2015-11-14)

## :sparkles: Features

- Implement custom elements update through atom-utils ([3c9bb193](https://github.com/abe33/atom-tablr/commit/3c9bb193e6c7a56f95dd35cb4c4ca23dc28c83ae))

## :arrow_up: Dependencies Update

- Bump version of atom-utils ([29af70ea](https://github.com/abe33/atom-tablr/commit/29af70eae3a824fe5b47b3f4b00140484de0fc06))

<a name="v0.6.4"></a>
# v0.6.4 (2015-11-13)

## :bug: Bug Fixes

- Fix use of atom.project.open in csv opener ([418fc9ed](https://github.com/abe33/atom-tablr/commit/418fc9ed224d9d6bd3f43d24ea96e345023ae764))

<a name="v0.6.4"></a>
# v0.6.4 (2015-11-13)

Just screwed up previous publication.

<a name="v0.6.2"></a>
# v0.6.2 (2015-11-13)

## :bug: Bug Fixes

- Fix broken deserialization tests ([64172d1b](https://github.com/abe33/atom-tablr/commit/64172d1b48fa0164fa14a8f24ab3a944c876f1bc))
- Fix confirm spy no longer working ([bba16568](https://github.com/abe33/atom-tablr/commit/bba16568f943ced72bbb42b645358630fb7a267c))
- Fix deprecated use of atom.project.open ([c9d81aaf](https://github.com/abe33/atom-tablr/commit/c9d81aaf7be3b4d683fd27ffb8317371c2bec77e))
- Fix use of the deprecated TextEditor constructor ([683c5ea6](https://github.com/abe33/atom-tablr/commit/683c5ea6c2e720fb8822a996f1a66b51db5186ea))

<a name="v0.6.1"></a>
# v0.6.1 (2015-10-27)

## :bug: Bug Fixes

- Fix bad selector for linux and windows keybindings ([31e6d0f7](https://github.com/abe33/atom-tablr/commit/31e6d0f7b52d9900516f2a118f7eab6195b2d64f))

<a name="v0.6.0"></a>
# v0.6.0 (2015-10-21)

## :sparkles: Features

- Add a new setting to define the default columns naming strategy. ([84260ecf](https://github.com/abe33/atom-tablr/commit/84260ecff56ff608d7dc505951ec0bba6cb50486), [#13](https://github.com/abe33/atom-tablr/issues/13))

<a name="v0.5.1"></a>
# v0.5.1 (2015-10-21)

## :bug: Bug Fixes

- Fix bad method used to retrieve the column count to find last column ([a6de5f83](https://github.com/abe33/atom-tablr/commit/a6de5f834973e8c9dc54517d16d58f1b7f13db4b), [#12](https://github.com/abe33/atom-tablr/issues/12))

<a name="v0.5.0"></a>
# v0.5.0 (2015-10-21)

## :sparkles: Features

- Add new setting to extend support to other extensions beside CSV ([f783c877](https://github.com/abe33/atom-tablr/commit/f783c8775372b11ede3db105b3c8cf4c3a7d25aa), [#11](https://github.com/abe33/atom-tablr/issues/11))

<a name="v0.4.0"></a>
# v0.4.0 (2015-10-07)

## :sparkles: Features

- Add a warning and stop operation when moving lines with an order defined on the table ([0a34bfaf](https://github.com/abe33/atom-tablr/commit/0a34bfaf19122b44dbf15c6c0d3058719a336363))
- Implement move lines up and down commands ([f61d61b6](https://github.com/abe33/atom-tablr/commit/f61d61b65c7d1651d3e9df61fee0db493ff01c91))

## :bug: Bug Fixes

- Fix saveAs not changing the csv editor path ([dbaf82b9](https://github.com/abe33/atom-tablr/commit/dbaf82b9f3e11f81344b7130cad4960fa074b613))

## Breaking Changes

- due to [147cdb55](https://github.com/abe33/atom-tablr/commit/147cdb55882ba375c4a06f8579259ee336cc9c4d), as the various custom elements names have been
changed, the custom CSS users wrote to adjust the table to their taste
will breaks.

<a name="v0.3.0"></a>
# v0.3.0 (2015-10-03)

## :sparkles: Features

- Add a go to line command mimicking the text editor one ([d65488f5](https://github.com/abe33/atom-tablr/commit/d65488f56a5e2e288b654b19e911276fb9039719))
- Implement handling of file change on disk while an editor is opened ([1a433466](https://github.com/abe33/atom-tablr/commit/1a433466918e383f5b184b9832208ef90d73abdd))
- Implement title and config changes on file rename ([0323a01b](https://github.com/abe33/atom-tablr/commit/0323a01bcb6c59b2995d0fc17fe758cb06192d26))

<a name="v0.2.4"></a>
# v0.2.4 (2015-10-01)

## :bug: Bug Fixes

- Fix preview table no longer constrained in cvs form ([1d9000c3](https://github.com/abe33/atom-tablr/commit/1d9000c39d905b087b2d6bd413da037d45833dbd))

<a name="v0.2.3"></a>
# v0.2.3 (2015-10-01)

## :art: Styling

- Make the package styles use the syntax theme rather than the ui one so that the tab and the pane item use the same background.
- Use relative font-size rather than absolute one.

a name="v0.2.2"></a>
# v0.2.2 (2015-09-29)

## :bug: Bug Fixes

- Fix cell cursor appearing on scrollbars ([2bc0bb16](https://github.com/abe33/atom-tablr/commit/2bc0bb163ebf4c6677c6de16ca41ce2c0d9b3688), [#5](https://github.com/abe33/atom-tablr/issues/5))

<a name="v0.2.1"></a>
# v0.2.1 (2015-09-28)

## :bug: Bug Fixes

- Prevent errors raised when opening a context menu during an edit ([1f7eb563](https://github.com/abe33/atom-tablr/commit/1f7eb563ce2eb47d5cfc4df6a47fa43c02fd06a2), [#7](https://github.com/abe33/atom-tablr/issues/7))
- Fix mini text editor styles polluted by themes ([711c1b1c](https://github.com/abe33/atom-tablr/commit/711c1b1ccba921f1f8dbdc1b37ecbdeea8eddef1), [#6](https://github.com/abe33/atom-tablr/issues/6))

<a name="v0.2.0"></a>
# v0.2.0 (2015-09-27)

## :sparkles: Features

- Implement displaying the whole content of active cell with ellipsis ([935c251b](https://github.com/abe33/atom-tablr/commit/935c251b524517ab84bb44fcf1189058525f6abc))
- Add commands to expand the width and height of columns and rows ([664e9080](https://github.com/abe33/atom-tablr/commit/664e9080a47024e627c0fa0ad7c348a272de8ac6))
- Implement a service to access tablr models ([855c72b0](https://github.com/abe33/atom-tablr/commit/855c72b014772ed2028fabf97467d97f1d341028))
