# style-check
XQuery library for style checking word-processing documents

## Pre-requisites
* In order to run the compiled stylesheet `styles2elems.sef`, the same version of saxon used to compile the stylesheet (this can be checked by inspecting `/package/@saxonVersion` in the `.sef` file) must be present in the BaseX `lib/` directory (not included here).
* `validator.jar` must be present in the etc/ directory of this distribution
* `style-schema.dtd` must be present in the dtd/ directory of this distribution
