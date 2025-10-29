package com.example.iotble.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import com.example.iotble.model.LocationData;
import com.example.iotble.service.LocationService;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * LocationControllerのユニットテスト
 * 
 * 正常系、異常系、境界値、エッジケースを網羅的にテストします
 */
@WebMvcTest(LocationController.class)
@DisplayName("LocationController テスト")
class LocationControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockitoBean
    private LocationService locationService;

    private LocationData validLocation;
    private LocalDateTime testTime;

    /**
     * 各テスト実行前の初期化処理
     */
    @BeforeEach
    void setUp() {
        testTime = LocalDateTime.of(2025, 1, 1, 12, 0, 0);
        validLocation = LocationData.builder()
                .id(1L)
                .deviceId("ESP32-001")
                .latitude(35.658581)
                .longitude(139.745433)
                .altitude(10.0)
                .accuracy(10.0)
                .rssi(-50)
                .timestamp(testTime)
                .createdAt(testTime)
                .build();
    }

    /**
     * POST /api/locations のテスト
     */
    @Nested
    @DisplayName("位置情報登録API")
    class CreateLocationTests {

        @Test
        @DisplayName("正常系: 有効な位置情報を登録できる")
        void testCreateLocation_Success() throws Exception {
            when(locationService.saveLocation(any(LocationData.class))).thenReturn(validLocation);

            mockMvc.perform(post("/api/locations")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(validLocation)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.deviceId").value("ESP32-001"))
                    .andExpect(jsonPath("$.latitude").value(35.658581))
                    .andExpect(jsonPath("$.longitude").value(139.745433));
        }

        @Test
        @DisplayName("境界値: 緯度の最小値(-90.0)で登録できる")
        void testCreateLocation_MinLatitude() throws Exception {
            LocationData minLatLocation = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(-90.0)
                    .longitude(0.0)
                    .timestamp(testTime)
                    .build();

            when(locationService.saveLocation(any(LocationData.class))).thenReturn(minLatLocation);

            mockMvc.perform(post("/api/locations")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(minLatLocation)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.latitude").value(-90.0));
        }

        @Test
        @DisplayName("境界値: 緯度の最大値(90.0)で登録できる")
        void testCreateLocation_MaxLatitude() throws Exception {
            LocationData maxLatLocation = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(90.0)
                    .longitude(0.0)
                    .timestamp(testTime)
                    .build();

            when(locationService.saveLocation(any(LocationData.class))).thenReturn(maxLatLocation);

            mockMvc.perform(post("/api/locations")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(maxLatLocation)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.latitude").value(90.0));
        }

        @Test
        @DisplayName("境界値: 経度の最小値(-180.0)で登録できる")
        void testCreateLocation_MinLongitude() throws Exception {
            LocationData minLonLocation = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(0.0)
                    .longitude(-180.0)
                    .timestamp(testTime)
                    .build();

            when(locationService.saveLocation(any(LocationData.class))).thenReturn(minLonLocation);

            mockMvc.perform(post("/api/locations")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(minLonLocation)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.longitude").value(-180.0));
        }

        @Test
        @DisplayName("境界値: 経度の最大値(180.0)で登録できる")
        void testCreateLocation_MaxLongitude() throws Exception {
            LocationData maxLonLocation = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(0.0)
                    .longitude(180.0)
                    .timestamp(testTime)
                    .build();

            when(locationService.saveLocation(any(LocationData.class))).thenReturn(maxLonLocation);

            mockMvc.perform(post("/api/locations")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(maxLonLocation)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.longitude").value(180.0));
        }

        @Test
        @DisplayName("異常系: デバイスIDがnullの場合エラーになる")
        void testCreateLocation_NullDeviceId() throws Exception {
            String invalidJson = "{\"deviceId\":null,\"latitude\":35.0,\"longitude\":139.0}";

            mockMvc.perform(post("/api/locations")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(invalidJson))
                    .andExpect(status().isBadRequest());
        }

        @Test
        @DisplayName("異常系: デバイスIDが空文字の場合エラーになる")
        void testCreateLocation_EmptyDeviceId() throws Exception {
            String invalidJson = "{\"deviceId\":\"\",\"latitude\":35.0,\"longitude\":139.0}";

            mockMvc.perform(post("/api/locations")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(invalidJson))
                    .andExpect(status().isBadRequest());
        }

        @Test
        @DisplayName("異常系: 緯度がnullの場合エラーになる")
        void testCreateLocation_NullLatitude() throws Exception {
            String invalidJson = "{\"deviceId\":\"ESP32-001\",\"latitude\":null,\"longitude\":139.0}";

            mockMvc.perform(post("/api/locations")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(invalidJson))
                    .andExpect(status().isBadRequest());
        }

        @Test
        @DisplayName("異常系: 経度がnullの場合エラーになる")
        void testCreateLocation_NullLongitude() throws Exception {
            String invalidJson = "{\"deviceId\":\"ESP32-001\",\"latitude\":35.0,\"longitude\":null}";

            mockMvc.perform(post("/api/locations")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(invalidJson))
                    .andExpect(status().isBadRequest());
        }

        @Test
        @DisplayName("異常系: JSONフォーマットが不正な場合エラーになる")
        void testCreateLocation_InvalidJson() throws Exception {
            String invalidJson = "{invalid json}";

            mockMvc.perform(post("/api/locations")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(invalidJson))
                    .andExpect(status().isBadRequest());
        }
    }

    /**
     * GET /api/locations のテスト
     */
    @Nested
    @DisplayName("全位置情報取得API")
    class GetAllLocationsTests {

        @Test
        @DisplayName("正常系: 全位置情報を取得できる")
        void testGetAllLocations_Success() throws Exception {
            List<LocationData> locations = Arrays.asList(validLocation);
            when(locationService.getAllLocations()).thenReturn(locations);

            mockMvc.perform(get("/api/locations"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$[0].deviceId").value("ESP32-001"))
                    .andExpect(jsonPath("$[0].latitude").value(35.658581));
        }

        @Test
        @DisplayName("エッジケース: データが0件の場合空配列を返す")
        void testGetAllLocations_EmptyList() throws Exception {
            when(locationService.getAllLocations()).thenReturn(Collections.emptyList());

            mockMvc.perform(get("/api/locations"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$").isArray())
                    .andExpect(jsonPath("$").isEmpty());
        }

        @Test
        @DisplayName("正常系: 複数の位置情報を取得できる")
        void testGetAllLocations_MultipleLocations() throws Exception {
            LocationData location2 = LocationData.builder()
                    .id(2L)
                    .deviceId("ESP32-002")
                    .latitude(35.681236)
                    .longitude(139.767125)
                    .timestamp(testTime)
                    .build();

            List<LocationData> locations = Arrays.asList(validLocation, location2);
            when(locationService.getAllLocations()).thenReturn(locations);

            mockMvc.perform(get("/api/locations"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$").isArray())
                    .andExpect(jsonPath("$.length()").value(2))
                    .andExpect(jsonPath("$[0].deviceId").value("ESP32-001"))
                    .andExpect(jsonPath("$[1].deviceId").value("ESP32-002"));
        }
    }

    /**
     * GET /api/locations/{id} のテスト
     */
    @Nested
    @DisplayName("ID指定位置情報取得API")
    class GetLocationByIdTests {

        @Test
        @DisplayName("正常系: 存在するIDで位置情報を取得できる")
        void testGetLocationById_Success() throws Exception {
            when(locationService.getLocationById(1L)).thenReturn(Optional.of(validLocation));

            mockMvc.perform(get("/api/locations/1"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.id").value(1))
                    .andExpect(jsonPath("$.deviceId").value("ESP32-001"));
        }

        @Test
        @DisplayName("異常系: 存在しないIDの場合404エラーになる")
        void testGetLocationById_NotFound() throws Exception {
            when(locationService.getLocationById(999L)).thenReturn(Optional.empty());

            mockMvc.perform(get("/api/locations/999"))
                    .andExpect(status().isNotFound());
        }

        @Test
        @DisplayName("境界値: ID=0で検索した場合")
        void testGetLocationById_ZeroId() throws Exception {
            when(locationService.getLocationById(0L)).thenReturn(Optional.empty());

            mockMvc.perform(get("/api/locations/0"))
                    .andExpect(status().isNotFound());
        }

        @Test
        @DisplayName("境界値: 最大Long値のIDで検索した場合")
        void testGetLocationById_MaxLongId() throws Exception {
            when(locationService.getLocationById(Long.MAX_VALUE)).thenReturn(Optional.empty());

            mockMvc.perform(get("/api/locations/" + Long.MAX_VALUE))
                    .andExpect(status().isNotFound());
        }
    }

    /**
     * GET /api/locations/device/{deviceId} のテスト
     */
    @Nested
    @DisplayName("デバイスID指定位置情報取得API")
    class GetLocationsByDeviceTests {

        @Test
        @DisplayName("正常系: デバイスIDで位置情報を取得できる")
        void testGetLocationsByDevice_Success() throws Exception {
            List<LocationData> locations = Arrays.asList(validLocation);
            when(locationService.getLocationsByDeviceId("ESP32-001")).thenReturn(locations);

            mockMvc.perform(get("/api/locations/device/ESP32-001"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$[0].deviceId").value("ESP32-001"));
        }

        @Test
        @DisplayName("エッジケース: 該当するデバイスIDがない場合空配列を返す")
        void testGetLocationsByDevice_NotFound() throws Exception {
            when(locationService.getLocationsByDeviceId("UNKNOWN")).thenReturn(Collections.emptyList());

            mockMvc.perform(get("/api/locations/device/UNKNOWN"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$").isArray())
                    .andExpect(jsonPath("$").isEmpty());
        }

        @Test
        @DisplayName("正常系: 同一デバイスの複数位置情報を取得できる")
        void testGetLocationsByDevice_MultipleLocations() throws Exception {
            LocationData location2 = LocationData.builder()
                    .id(2L)
                    .deviceId("ESP32-001")
                    .latitude(35.681236)
                    .longitude(139.767125)
                    .timestamp(testTime.plusMinutes(10))
                    .build();

            List<LocationData> locations = Arrays.asList(validLocation, location2);
            when(locationService.getLocationsByDeviceId("ESP32-001")).thenReturn(locations);

            mockMvc.perform(get("/api/locations/device/ESP32-001"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.length()").value(2))
                    .andExpect(jsonPath("$[0].deviceId").value("ESP32-001"))
                    .andExpect(jsonPath("$[1].deviceId").value("ESP32-001"));
        }
    }

    /**
     * DELETE /api/locations/{id} のテスト
     */
    @Nested
    @DisplayName("位置情報削除API")
    class DeleteLocationTests {

        @Test
        @DisplayName("正常系: 存在するIDの位置情報を削除できる")
        void testDeleteLocation_Success() throws Exception {
            when(locationService.deleteLocation(1L)).thenReturn(true);

            mockMvc.perform(delete("/api/locations/1"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.message").value("位置情報を削除しました"));
        }

        @Test
        @DisplayName("異常系: 存在しないIDの場合404エラーになる")
        void testDeleteLocation_NotFound() throws Exception {
            when(locationService.deleteLocation(999L)).thenReturn(false);

            mockMvc.perform(delete("/api/locations/999"))
                    .andExpect(status().isNotFound());
        }

        @Test
        @DisplayName("境界値: ID=0の削除を試みた場合")
        void testDeleteLocation_ZeroId() throws Exception {
            when(locationService.deleteLocation(0L)).thenReturn(false);

            mockMvc.perform(delete("/api/locations/0"))
                    .andExpect(status().isNotFound());
        }
    }

    /**
     * GET /api/locations/recent のテスト
     */
    @Nested
    @DisplayName("最新位置情報取得API")
    class GetRecentLocationsTests {

        @Test
        @DisplayName("正常系: 最新の位置情報を取得できる")
        void testGetRecentLocations_Success() throws Exception {
            List<LocationData> locations = Arrays.asList(validLocation);
            when(locationService.getRecentLocations()).thenReturn(locations);

            mockMvc.perform(get("/api/locations/recent"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$[0].deviceId").value("ESP32-001"));
        }

        @Test
        @DisplayName("エッジケース: データが0件の場合空配列を返す")
        void testGetRecentLocations_EmptyList() throws Exception {
            when(locationService.getRecentLocations()).thenReturn(Collections.emptyList());

            mockMvc.perform(get("/api/locations/recent"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$").isArray())
                    .andExpect(jsonPath("$").isEmpty());
        }
    }

    /**
     * GET /api/stats のテスト
     */
    @Nested
    @DisplayName("統計情報取得API")
    class GetStatsTests {

        @Test
        @DisplayName("正常系: 統計情報を取得できる")
        void testGetStats_Success() throws Exception {
            when(locationService.getAllLocations()).thenReturn(Arrays.asList(validLocation));
            when(locationService.getDeviceCount()).thenReturn(1L);

            mockMvc.perform(get("/api/stats"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.totalLocations").value(1))
                    .andExpect(jsonPath("$.deviceCount").value(1))
                    .andExpect(jsonPath("$.timestamp").exists());
        }

        @Test
        @DisplayName("エッジケース: データが0件の場合も統計情報を返す")
        void testGetStats_EmptyData() throws Exception {
            when(locationService.getAllLocations()).thenReturn(Collections.emptyList());
            when(locationService.getDeviceCount()).thenReturn(0L);

            mockMvc.perform(get("/api/stats"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.totalLocations").value(0))
                    .andExpect(jsonPath("$.deviceCount").value(0));
        }
    }
}
