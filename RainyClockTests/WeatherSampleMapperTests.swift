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
