import AppKit

// POM (Ponas Obuolys Metrika) – Claude limitai macOS meniu juostoje.
// Programa gyvena tik prie laikrodžio, todėl doke jos ikonos nėra (.accessory).
//
// `NSApplication.delegate` yra silpna nuoroda, o Swift vietinį kintamąjį gali atlaisvinti
// iškart po paskutinio panaudojimo. Todėl delegato gyvavimas pratęsiamas aiškiai:
// be to jis būtų sunaikintas dar nespėjus sukurti meniu juostos elemento.

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) {
        application.run()
    }
}
