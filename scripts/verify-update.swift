import CryptoKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 4,
      let publicData = Data(base64Encoded: try String(contentsOfFile: arguments[1], encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)),
      let signature = Data(base64Encoded: arguments[3]) else {
    fputs("Expected public key file, archive and EdDSA signature.\n", stderr)
    exit(1)
}
let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicData)
let archive = try Data(contentsOf: URL(fileURLWithPath: arguments[2]), options: .mappedIfSafe)
guard key.isValidSignature(signature, for: archive) else {
    fputs("Update signature does not match the public key shipped in POM.\n", stderr)
    exit(1)
}
print("Update verified against POM's shipped public key.")
