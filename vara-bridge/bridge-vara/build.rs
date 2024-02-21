// extern crate bridge_io;
use bridge_vara_io::BridgeMetadata;

fn main() {
    gear_wasm_builder::build_with_metadata::<BridgeMetadata>();
}
