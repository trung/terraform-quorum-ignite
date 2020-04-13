This submodule is used to start a Quorum Network in Docker via `terraform-provider-docker`

This is best used along with the main module and submodule `docker-helper` to simplify the inputs.

## Environment Variables

* `ALWAYS_REFRESH`: when `geth` container starts, it always replaces its data folder from host data folder.
* `ADDITIONAL_GETH_ARGS`: string value being appended to `geth`

Please refer to examples for more detail usage.