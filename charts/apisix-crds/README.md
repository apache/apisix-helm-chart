# CRDs for Apache APISIX ingress controller

You can use this chart to install the CRDs outside of the APISIX Ingress controller chart.
Ensure that you use the `--skip-crds` flag when installing the APISIX Ingress controller chart.

The Gateway API CRDs will not be installed by default; set the `gatewayApi.enabled` value to `true` to install them.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| gatewayApi.channel | string | `"standard"` | The Gateway API channel to use. |
| gatewayApi.enabled | bool | `false` | Whether or not the Gateway API CRDs will be installed. |
| gatewayApi.verify.experimental | string | `"d3c20dd4c0431936567a6917ca931f6dced1310242be62b9eca07bd9892e2025"` | Gateway API Experimental channel install bundle sha256 hash |
| gatewayApi.verify.standard | string | `"daa2999f0978ba3e43b65fec179f82a1a690649da10aa5c7c5871165477368f8"` | Gateway API Standard channel install bundle sha256 hash |
