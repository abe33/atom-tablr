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
