import CoreLocation
import Foundation
import MapKit

struct ResolvedMapLocation: Sendable {
    var latitude: Double
    var longitude: Double
    var displayAddress: String?
    var resolution: AddressResolution

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var mapItem: MKMapItem {
        MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
    }
}

enum AddressResolution: Sendable, Equatable {
    case exact
    case suggested
}

actor MapItemResolver {
    private let geocoder = CLGeocoder()
    private let googlePlaceResolver = GooglePlaceResolver()

    func resolve(_ rawAddress: String) async throws -> ResolvedMapLocation {
        try await resolve(queries: Self.candidateQueries(for: rawAddress), fallbackAddress: rawAddress)
    }

    func canResolvePrecisely(_ rawAddress: String) async -> Bool {
        let queries = Self.strictCandidateQueries(for: rawAddress)
        do {
            if try await resolveWithAppleMaps(queries: queries) != nil {
                return true
            }
        } catch {
        }

        return await googlePlaceResolver.resolve(queries) != nil
    }

    private func resolve(queries: [String], fallbackAddress: String) async throws -> ResolvedMapLocation {
        if let location = try await resolveWithAppleMaps(queries: queries) {
            return location
        }

        if let location = await googlePlaceResolver.resolve(queries) {
            return location
        }

        throw MapKitRouteWeatherServiceError.addressNotFound(fallbackAddress)
    }

    private func resolveWithAppleMaps(queries: [String]) async throws -> ResolvedMapLocation? {
        let strictQueryCount = Self.strictCandidateQueries(for: queries.first ?? "").count
        for (index, query) in queries.enumerated() {
            let resolution: AddressResolution = index < strictQueryCount ? .exact : .suggested
            if let location = try await geocode(query, resolution: resolution) {
                return location
            }

            if let location = try await search(query, resolution: resolution) {
                return location
            }
        }

        return nil
    }

    private func geocode(_ query: String, resolution: AddressResolution) async throws -> ResolvedMapLocation? {
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            guard let placemark = placemarks.first(where: { $0.location != nil }),
                  let coordinate = placemark.location?.coordinate else {
                return nil
            }
            let displayAddress = Self.displayAddress(for: placemark)
            guard Self.isAcceptableResolvedAddress(query: query, displayAddress: displayAddress) else {
                return nil
            }

            return ResolvedMapLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                displayAddress: displayAddress,
                resolution: resolution
            )
        } catch let error as CLError where error.code == .geocodeFoundNoResult || error.code == .geocodeFoundPartialResult || error.code == .network {
            return nil
        } catch {
            return nil
        }
    }

    private func search(_ query: String, resolution: AddressResolution) async throws -> ResolvedMapLocation? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        request.region = Self.taiwanRegion

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let mapItem = response.mapItems.first(where: { $0.placemark.location != nil }),
                  let coordinate = mapItem.placemark.location?.coordinate else {
                return nil
            }
            let displayAddress = Self.displayAddress(for: mapItem)
            guard Self.isAcceptableResolvedAddress(query: query, displayAddress: displayAddress) else {
                return nil
            }

            return ResolvedMapLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                displayAddress: displayAddress,
                resolution: resolution
            )
        } catch {
            return nil
        }
    }

    static func candidateQueries(for rawAddress: String) -> [String] {
        var queries = strictCandidateQueries(for: rawAddress)
        let normalized = normalize(rawAddress)
        queries.append(contentsOf: taiwanSemiconductorQueries(from: normalized))

        return deduplicatedQueries(queries)
    }

    static func strictCandidateQueries(for rawAddress: String) -> [String] {
        let normalized = normalize(rawAddress)
        var queries = [normalized]
        let withoutPostalCode = removeTaiwanPostalCode(from: normalized)
        if withoutPostalCode != normalized {
            queries.append(withoutPostalCode)
        }

        let trimmedUnit = removeTaiwanFloorAndUnitDetails(from: normalized)
        if trimmedUnit != normalized {
            queries.append(trimmedUnit)
        }

        let commaParts = normalized
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if commaParts.count > 1 {
            for part in commaParts {
                queries.append(part)
                queries.append(removeTaiwanPostalCode(from: part))
            }
        }

        let dashHead = normalized.components(separatedBy: " - ").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if dashHead.count >= 4 {
            queries.append(dashHead)
        }

        return deduplicatedQueries(queries)
    }

    private static func deduplicatedQueries(_ queries: [String]) -> [String] {
        return queries.reduce(into: [String]()) { result, query in
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2, !result.contains(trimmed) else {
                return
            }

            result.append(trimmed)
        }
    }

    private static func normalize(_ rawAddress: String) -> String {
        rawAddress
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "臺", with: "台")
            .replacingOccurrences(of: "號之", with: "號 ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removeTaiwanPostalCode(from address: String) -> String {
        address
            .replacingOccurrences(of: #"(^|[\s,，])\d{3,5}(?=\s*台)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removeTaiwanFloorAndUnitDetails(from address: String) -> String {
        address
            .replacingOccurrences(of: #"\s*\d+\s*樓.*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*\d+\s*F.*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s*之\s*\d+\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func taiwanSemiconductorQueries(from normalizedAddress: String) -> [String] {
        guard normalizedAddress.localizedStandardContains("台灣積體電路")
            || normalizedAddress.localizedStandardContains("台积电")
            || normalizedAddress.localizedStandardContains("台積電")
            || normalizedAddress.localizedStandardContains("TSMC") else {
            return []
        }

        let addressSide = normalizedAddress
            .components(separatedBy: ",")
            .dropFirst()
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let addressWithoutPostalCode = removeTaiwanPostalCode(from: addressSide.isEmpty ? normalizedAddress : addressSide)
        var queries = [
            "台積電 南科",
            "台積電 南科北路1號",
            "台積電 台南 南科",
            "TSMC 台南 南科",
            "TSMC Fab 18",
            "南科北路1號 台南市新市區",
            "台南市新市區南科北路1號"
        ]

        if !addressWithoutPostalCode.isEmpty {
            queries.insert(addressWithoutPostalCode, at: 0)
            queries.insert("台積電 \(addressWithoutPostalCode)", at: 1)
        }

        return queries
    }

    private static func displayAddress(for placemark: CLPlacemark) -> String? {
        [
            placemark.name,
            placemark.thoroughfare,
            placemark.subLocality,
            placemark.locality,
            placemark.administrativeArea
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .reduce(into: [String]()) { result, part in
            guard !result.contains(part) else {
                return
            }
            result.append(part)
        }
        .joined(separator: ", ")
        .nilIfEmpty
    }

    private static func displayAddress(for mapItem: MKMapItem) -> String? {
        [
            mapItem.name,
            mapItem.placemark.title
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
    }

    static func isAcceptableResolvedAddress(query: String, displayAddress: String?) -> Bool {
        let normalizedQuery = normalizeForMatching(query)
        guard normalizedQuery.count >= 2 else {
            return false
        }

        guard let displayAddress,
              !displayAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }

        let normalizedDisplayAddress = normalizeForMatching(displayAddress)
        guard !normalizedDisplayAddress.isEmpty else {
            return false
        }

        if normalizedDisplayAddress.contains(normalizedQuery) || normalizedQuery.contains(normalizedDisplayAddress) {
            return true
        }

        let tokens = meaningfulMatchTokens(from: query)
        guard !tokens.isEmpty else {
            return false
        }

        let matchedTokens = tokens.filter { normalizedDisplayAddress.contains($0) }
        let hasImportantAlphanumericToken = tokens.contains { token in
            isASCIIAlphanumericIdentifier(token)
        }
        if hasImportantAlphanumericToken,
           !matchedTokens.contains(where: { token in
               isASCIIAlphanumericIdentifier(token)
           }) {
            return false
        }

        if isSpecificTaiwanStreetAddress(query) {
            return true
        }

        if normalizedQuery.count <= 8 {
            return !matchedTokens.isEmpty
        }

        return matchedTokens.count >= min(2, tokens.count)
    }

    private static func meaningfulMatchTokens(from query: String) -> [String] {
        let normalized = query
            .replacingOccurrences(of: "臺", with: "台")
            .lowercased()
        var tokens: [String] = []
        appendMatches(from: normalized, pattern: #"[a-z]+\d+[a-z\d]*|\d+[a-z]+[a-z\d]*"#, to: &tokens)
        appendMatches(from: normalized, pattern: #"[\p{Han}]{2,}(?:市|縣|區|鎮|鄉|村|里|路|街|大道|園區)"#, to: &tokens)
        appendMatches(from: normalized, pattern: #"\d+號"#, to: &tokens)
        tokens.append(contentsOf: taiwanPlaceTokens(from: normalized))

        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: ",，、-()（）"))
        normalized
            .components(separatedBy: separators)
            .map { normalizeForMatching($0) }
            .filter { token in
                token.count >= 2
                    && !token.allSatisfy(\.isNumber)
                    && token != "台灣"
                    && token != "taiwan"
            }
            .forEach { tokens.append($0) }

        return tokens.reduce(into: [String]()) { result, token in
            guard !result.contains(token) else {
                return
            }
            result.append(token)
        }
    }

    private static func taiwanPlaceTokens(from text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        let markers: Set<Character> = ["市", "縣", "區", "鎮", "鄉", "村", "里", "路", "街"]

        for character in text {
            current.append(character)
            if markers.contains(character) {
                let token = normalizeForMatching(current)
                if token.count >= 2 {
                    tokens.append(token)
                }
                current = ""
            }
        }

        return tokens
    }

    private static func isSpecificTaiwanStreetAddress(_ query: String) -> Bool {
        let normalized = query
            .replacingOccurrences(of: "臺", with: "台")
            .lowercased()
        let hasHouseNumber = normalized.range(of: #"\d+\s*號"#, options: .regularExpression) != nil
        let hasStreet = normalized.contains("路")
            || normalized.contains("街")
            || normalized.contains("大道")
        let hasLocality = normalized.contains("市")
            || normalized.contains("縣")
            || normalized.contains("區")
            || normalized.contains("鄉")
            || normalized.contains("鎮")

        return hasHouseNumber && hasStreet && hasLocality
    }

    private static func isASCIIAlphanumericIdentifier(_ token: String) -> Bool {
        let hasASCIILetter = token.unicodeScalars.contains { scalar in
            (65...90).contains(Int(scalar.value)) || (97...122).contains(Int(scalar.value))
        }
        let hasDigit = token.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }

        return hasASCIILetter && hasDigit
    }

    private static func appendMatches(from text: String, pattern: String, to tokens: inout [String]) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in regex.matches(in: text, range: range) {
            guard let tokenRange = Range(match.range, in: text) else {
                continue
            }
            let token = normalizeForMatching(String(text[tokenRange]))
            if token.count >= 2 {
                tokens.append(token)
            }
        }
    }

    private static func normalizeForMatching(_ value: String) -> String {
        value
            .replacingOccurrences(of: "臺", with: "台")
            .lowercased()
            .replacingOccurrences(of: #"[\s,，、。.\-_/()（）]+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let taiwanRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 23.6978, longitude: 120.9605),
        span: MKCoordinateSpan(latitudeDelta: 4.5, longitudeDelta: 4.5)
    )
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
