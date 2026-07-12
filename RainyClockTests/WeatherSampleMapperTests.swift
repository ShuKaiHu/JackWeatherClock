import XCTest
@testable import RainyClock

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
}
