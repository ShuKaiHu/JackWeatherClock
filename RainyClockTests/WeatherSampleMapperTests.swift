import CoreLocation
import XCTest
@testable import RainyClock

final class RoutePolylineSamplerTests: XCTestCase {
    func testDegenerateRoutesProduceNoInteriorSamples() {
        // The sampler deleted in the 1.6.5 cleanup trapped on these.
        XCTAssertEqual(RoutePolylineSampler.interiorSamplePoints(along: []).count, 0)
        XCTAssertEqual(
            RoutePolylineSampler.interiorSamplePoints(along: [
                CLLocationCoordinate2D(latitude: 25.0, longitude: 121.5)
            ]).count,
            0
        )
        XCTAssertEqual(
            RoutePolylineSampler.interiorSamplePoints(along: [
                CLLocationCoordinate2D(latitude: 25.0, longitude: 121.5),
                CLLocationCoordinate2D(latitude: 25.0, longitude: 121.5)
            ]).count,
            0
        )
    }

    func testShortCommutesRelyOnTheEndpointsAlone() {
        // ~2.2 km straight line: below the 4 km floor.
        let samples = RoutePolylineSampler.interiorSamplePoints(along: [
            CLLocationCoordinate2D(latitude: 25.03, longitude: 121.50),
            CLLocationCoordinate2D(latitude: 25.05, longitude: 121.50)
        ])
        XCTAssertEqual(samples.count, 0)
    }

    func testMediumCommutesSampleTheMidpoint() {
        // ~11 km straight line north: one interior sample at the midpoint.
        let samples = RoutePolylineSampler.interiorSamplePoints(along: [
            CLLocationCoordinate2D(latitude: 25.0, longitude: 121.5),
            CLLocationCoordinate2D(latitude: 25.1, longitude: 121.5)
        ])
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[0].latitude, 25.05, accuracy: 1e-6)
        XCTAssertEqual(samples[0].longitude, 121.5, accuracy: 1e-6)
    }

    func testLongCommutesSampleQuarterPoints() {
        // ~33 km: quarter, mid, three-quarter.
        let samples = RoutePolylineSampler.interiorSamplePoints(along: [
            CLLocationCoordinate2D(latitude: 25.0, longitude: 121.5),
            CLLocationCoordinate2D(latitude: 25.3, longitude: 121.5)
        ])
        XCTAssertEqual(samples.count, 3)
        XCTAssertEqual(samples[0].latitude, 25.075, accuracy: 1e-6)
        XCTAssertEqual(samples[1].latitude, 25.15, accuracy: 1e-6)
        XCTAssertEqual(samples[2].latitude, 25.225, accuracy: 1e-6)
    }

    func testMidpointInterpolatesWithinTheContainingSegment() {
        // Uneven vertices: 0 → 8 km → 10 km. The midpoint (5 km) sits inside
        // the first segment, not on a vertex.
        let samples = RoutePolylineSampler.interiorSamplePoints(along: [
            CLLocationCoordinate2D(latitude: 25.0, longitude: 121.5),
            CLLocationCoordinate2D(latitude: 25.072, longitude: 121.5),
            CLLocationCoordinate2D(latitude: 25.09, longitude: 121.5)
        ])
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[0].latitude, 25.045, accuracy: 1e-3)
    }

    func testInteriorSegmentNamesDescribeThePositionAlongTheRoute() {
        XCTAssertEqual(
            MapKitRouteWeatherService.interiorSegmentName(index: 0, total: 1),
            String(localized: "segment_route_half")
        )

        let names = (0..<3).map { MapKitRouteWeatherService.interiorSegmentName(index: $0, total: 3) }
        XCTAssertEqual(names, [
            String(localized: "segment_route_quarter"),
            String(localized: "segment_route_half"),
            String(localized: "segment_route_three_quarter")
        ])
    }

    /// The labels above are derived from the position, so they only stay true
    /// while the sampler keeps spacing its points evenly.
    func testSampleFractionsAreEvenlySpacedSoTheNamesStayTrue() {
        for length in [10_000.0, 40_000.0] {
            let fractions = RoutePolylineSampler.interiorSampleFractions(forRouteLength: length)
            let expected = (0..<fractions.count).map { Double($0 + 1) / Double(fractions.count + 1) }
            XCTAssertEqual(fractions, expected, "route length \(length)")
        }

        XCTAssertTrue(RoutePolylineSampler.interiorSampleFractions(forRouteLength: 3_000).isEmpty)
    }
}

final class WeatherSampleMapperTests: XCTestCase {
    func testConditionMappingUsesRainThreshold() {
        XCTAssertEqual(WeatherSampleMapper.condition(for: 0.5), .rain)
        XCTAssertEqual(WeatherSampleMapper.condition(for: 0.8), .rain)
    }

    func testConditionMappingUsesCloudyBand() {
        XCTAssertEqual(WeatherSampleMapper.condition(for: 0.2), .cloudy)
        XCTAssertEqual(WeatherSampleMapper.condition(for: 0.49), .cloudy)
    }

    func testConditionMappingUsesClearBand() {
        XCTAssertEqual(WeatherSampleMapper.condition(for: 0.0), .clear)
        XCTAssertEqual(WeatherSampleMapper.condition(for: 0.19), .clear)
    }

    func testMapItemResolverBuildsFallbackQueriesForPastedTSMCAddress() {
        let queries = MapItemResolver.candidateQueries(
            for: "台灣積體電路製造股份有限公司, 74144台灣台南市科學園區南科北路1號"
        )

        XCTAssertTrue(queries.contains("台灣台南市科學園區南科北路1號"))
        XCTAssertTrue(queries.contains("台積電 南科北路1號"))
        XCTAssertTrue(queries.contains("台南市新市區南科北路1號"))
    }

    func testMapItemResolverRejectsLooseRoadMatchForTSMCFabKeyword() {
        XCTAssertFalse(MapItemResolver.isAcceptableResolvedAddress(
            query: "台積電 F18A",
            displayAddress: "Heping Rd"
        ))
    }

    func testMapItemResolverAcceptsRelevantTaiwanRoadMatch() {
        XCTAssertTrue(MapItemResolver.isAcceptableResolvedAddress(
            query: "台南市新市區南科北路1號",
            displayAddress: "南科北路1號, 新市區, 台南市"
        ))
    }

    func testMapItemResolverAcceptsSpecificAddressWhenAppleReturnsTransliteration() {
        XCTAssertTrue(MapItemResolver.isAcceptableResolvedAddress(
            query: "生態街59號, 台灣臺南市安南區海南里",
            displayAddress: "No. 59 Shengtai St, Shengtai St, Hainan Village, Annan District, Tainan City"
        ))
    }

    func testMapItemResolverRejectsPostalCodeOnlySuggestion() {
        let queries = MapItemResolver.candidateQueries(
            for: "台灣積體電路製造股份有限公司, 74144台灣台南市科學園區南科北路1號"
        )

        XCTAssertFalse(queries.contains("74144"))
        XCTAssertFalse(MapItemResolver.isAcceptableResolvedAddress(
            query: "74144",
            displayAddress: "74144"
        ))
    }

    func testMapItemResolverRejectsUnrelatedSpecificStreetMatch() {
        XCTAssertFalse(MapItemResolver.isAcceptableResolvedAddress(
            query: "自由路271號, 台灣台南市善化區",
            displayAddress: "Heping Rd"
        ))
    }

    func testMapItemResolverAcceptsRomanizedDisplayOutsideTainan() {
        XCTAssertTrue(MapItemResolver.isAcceptableResolvedAddress(
            query: "中正路100號, 台北市中山區",
            displayAddress: "No. 100, Zhongzheng Rd, Zhongshan District, Taipei City"
        ))
        XCTAssertTrue(MapItemResolver.isAcceptableResolvedAddress(
            query: "中山路50號, 高雄市前金區",
            displayAddress: "No. 50, Zhongshan Rd, Qianjin District, Kaohsiung City"
        ))
    }

    func testMapItemResolverAcceptsHashStyleHouseNumber() {
        XCTAssertTrue(MapItemResolver.isAcceptableResolvedAddress(
            query: "生態街59號, 台南市安南區",
            displayAddress: "#59 Shengtai St, Annan District, Tainan City"
        ))
    }

    func testMapItemResolverUsesDynamicTransliterationForUnlistedLocality() {
        XCTAssertTrue(MapItemResolver.isAcceptableResolvedAddress(
            query: "中正路100號, 桃園市中壢區",
            displayAddress: "No. 100, Zhongzheng Rd, Zhongli District, Taoyuan City"
        ))
        // District-only display: only the dynamic transliteration path can accept this.
        XCTAssertTrue(MapItemResolver.isAcceptableResolvedAddress(
            query: "中正路100號, 桃園市中壢區",
            displayAddress: "No. 100, Zhongzheng Rd, Zhongli District"
        ))
    }

    func testMapItemResolverRejectsDifferentHouseNumberInHanDisplay() {
        XCTAssertFalse(MapItemResolver.isAcceptableResolvedAddress(
            query: "南科北路1號, 台南市新市區",
            displayAddress: "台南市新市區南科北路231號"
        ))
    }

    func testMapItemResolverRejectsBareLocalityForSpecificStreetQuery() {
        XCTAssertFalse(MapItemResolver.isAcceptableResolvedAddress(
            query: "自由路271號, 台南市善化區",
            displayAddress: "台南市"
        ))
    }

    func testMapItemResolverRejectsWrongCityWithMatchingStreetName() {
        XCTAssertFalse(MapItemResolver.isAcceptableResolvedAddress(
            query: "民生路25號, 台北市大同區",
            displayAddress: "No. 25, Minsheng Rd, Banqiao District, New Taipei City"
        ))
    }

    func testMapItemResolverAcceptsEnglishPOIWithLocalizedAddressDisplay() {
        XCTAssertTrue(MapItemResolver.isAcceptableResolvedAddress(
            query: "Taipei Main Station",
            displayAddress: "3 Beiping W Rd, Zhongzheng District, Taipei City"
        ))
    }

    func testMapItemResolverRejectsNewTaipeiFragmentForEnglishTaipeiQuery() {
        XCTAssertFalse(MapItemResolver.isAcceptableResolvedAddress(
            query: "Taipei Main Station",
            displayAddress: "Maan, Fushan Village, Wulai District, New Taipei City"
        ))
    }

    func testMapItemResolverRejectsEnglishQueryWithWrongCity() {
        XCTAssertFalse(MapItemResolver.isAcceptableResolvedAddress(
            query: "Zhongzheng Rd, Taipei City",
            displayAddress: "Zhongzheng Rd, Qianjin District, Kaohsiung City"
        ))
    }

    func testPreferredSearchLocaleFollowsQueryLanguage() {
        XCTAssertEqual(MapItemResolver.preferredSearchLocale(for: "台北市中正區北平西路3號").identifier, "zh-Hant-TW")
        XCTAssertEqual(MapItemResolver.preferredSearchLocale(for: "Taipei Main Station").identifier, "en-US")
        // Mixed input keeps Chinese results.
        XCTAssertEqual(MapItemResolver.preferredSearchLocale(for: "台積電 Fab 18, Tainan").identifier, "zh-Hant-TW")
    }

    func testMapItemResolverAcceptsStreetsNamedAfterCounties() {
        // 金門街 is a Taipei street; the county name inside it must not register as a
        // city mention and trigger the wrong-city rejection.
        XCTAssertTrue(MapItemResolver.isAcceptableResolvedAddress(
            query: "中正區金門街10號",
            displayAddress: "No. 10 Jinmen St, Zhongzheng District, Taipei City"
        ))
        XCTAssertTrue(MapItemResolver.isAcceptableResolvedAddress(
            query: "基隆路100號, 台北市大安區",
            displayAddress: "No. 100, Keelung Rd, Da'an District"
        ))
    }
}
