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
