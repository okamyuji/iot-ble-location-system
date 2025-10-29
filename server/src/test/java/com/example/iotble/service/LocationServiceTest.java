package com.example.iotble.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.example.iotble.model.LocationData;
import com.example.iotble.repository.LocationRepository;

/**
 * LocationServiceのユニットテスト
 * 
 * 正常系、異常系、境界値、エッジケースを網羅的にテストします
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("LocationService テスト")
class LocationServiceTest {

    @Mock
    private LocationRepository locationRepository;

    @InjectMocks
    private LocationServiceImpl locationService;

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
     * saveLocation のテスト
     */
    @Nested
    @DisplayName("位置情報保存")
    class SaveLocationTests {

        @Test
        @DisplayName("正常系: 位置情報を保存できる")
        void testSaveLocation_Success() {
            when(locationRepository.save(any(LocationData.class))).thenReturn(validLocation);

            LocationData saved = locationService.saveLocation(validLocation);

            assertNotNull(saved);
            assertEquals("ESP32-001", saved.getDeviceId());
            assertEquals(35.658581, saved.getLatitude());
            assertEquals(139.745433, saved.getLongitude());
            verify(locationRepository, times(1)).save(any(LocationData.class));
        }

        @Test
        @DisplayName("正常系: タイムスタンプがnullの場合自動設定される")
        void testSaveLocation_NullTimestamp() {
            LocationData locationWithoutTimestamp = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(35.658581)
                    .longitude(139.745433)
                    .build();

            when(locationRepository.save(any(LocationData.class))).thenAnswer(invocation -> {
                LocationData arg = invocation.getArgument(0);
                assertNotNull(arg.getTimestamp(), "タイムスタンプが自動設定されるべき");
                return arg;
            });

            LocationData saved = locationService.saveLocation(locationWithoutTimestamp);

            assertNotNull(saved.getTimestamp());
            verify(locationRepository, times(1)).save(any(LocationData.class));
        }

        @Test
        @DisplayName("境界値: 緯度-90.0の位置情報を保存できる")
        void testSaveLocation_MinLatitude() {
            LocationData minLatLocation = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(-90.0)
                    .longitude(0.0)
                    .timestamp(testTime)
                    .build();

            when(locationRepository.save(any(LocationData.class))).thenReturn(minLatLocation);

            LocationData saved = locationService.saveLocation(minLatLocation);

            assertEquals(-90.0, saved.getLatitude());
        }

        @Test
        @DisplayName("境界値: 緯度90.0の位置情報を保存できる")
        void testSaveLocation_MaxLatitude() {
            LocationData maxLatLocation = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(90.0)
                    .longitude(0.0)
                    .timestamp(testTime)
                    .build();

            when(locationRepository.save(any(LocationData.class))).thenReturn(maxLatLocation);

            LocationData saved = locationService.saveLocation(maxLatLocation);

            assertEquals(90.0, saved.getLatitude());
        }

        @Test
        @DisplayName("境界値: 経度-180.0の位置情報を保存できる")
        void testSaveLocation_MinLongitude() {
            LocationData minLonLocation = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(0.0)
                    .longitude(-180.0)
                    .timestamp(testTime)
                    .build();

            when(locationRepository.save(any(LocationData.class))).thenReturn(minLonLocation);

            LocationData saved = locationService.saveLocation(minLonLocation);

            assertEquals(-180.0, saved.getLongitude());
        }

        @Test
        @DisplayName("境界値: 経度180.0の位置情報を保存できる")
        void testSaveLocation_MaxLongitude() {
            LocationData maxLonLocation = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(0.0)
                    .longitude(180.0)
                    .timestamp(testTime)
                    .build();

            when(locationRepository.save(any(LocationData.class))).thenReturn(maxLonLocation);

            LocationData saved = locationService.saveLocation(maxLonLocation);

            assertEquals(180.0, saved.getLongitude());
        }

        @Test
        @DisplayName("エッジケース: オプション項目がnullでも保存できる")
        void testSaveLocation_OptionalFieldsNull() {
            LocationData minimalLocation = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(35.658581)
                    .longitude(139.745433)
                    .timestamp(testTime)
                    .build();

            when(locationRepository.save(any(LocationData.class))).thenReturn(minimalLocation);

            LocationData saved = locationService.saveLocation(minimalLocation);

            assertNotNull(saved);
            assertNull(saved.getAltitude());
            assertNull(saved.getAccuracy());
            assertNull(saved.getRssi());
        }
    }

    /**
     * getAllLocations のテスト
     */
    @Nested
    @DisplayName("全位置情報取得")
    class GetAllLocationsTests {

        @Test
        @DisplayName("正常系: 全位置情報を取得できる")
        void testGetAllLocations_Success() {
            List<LocationData> locations = Arrays.asList(validLocation);
            when(locationRepository.findAll()).thenReturn(locations);

            List<LocationData> result = locationService.getAllLocations();

            assertNotNull(result);
            assertEquals(1, result.size());
            assertEquals("ESP32-001", result.get(0).getDeviceId());
            verify(locationRepository, times(1)).findAll();
        }

        @Test
        @DisplayName("エッジケース: データが0件の場合空リストを返す")
        void testGetAllLocations_EmptyList() {
            when(locationRepository.findAll()).thenReturn(Collections.emptyList());

            List<LocationData> result = locationService.getAllLocations();

            assertNotNull(result);
            assertTrue(result.isEmpty());
            verify(locationRepository, times(1)).findAll();
        }

        @Test
        @DisplayName("正常系: 複数の位置情報を取得できる")
        void testGetAllLocations_MultipleLocations() {
            LocationData location2 = LocationData.builder()
                    .id(2L)
                    .deviceId("ESP32-002")
                    .latitude(35.681236)
                    .longitude(139.767125)
                    .timestamp(testTime)
                    .build();

            List<LocationData> locations = Arrays.asList(validLocation, location2);
            when(locationRepository.findAll()).thenReturn(locations);

            List<LocationData> result = locationService.getAllLocations();

            assertEquals(2, result.size());
        }
    }

    /**
     * getLocationsByDeviceId のテスト
     */
    @Nested
    @DisplayName("デバイスID指定位置情報取得")
    class GetLocationsByDeviceIdTests {

        @Test
        @DisplayName("正常系: デバイスIDで位置情報を取得できる")
        void testGetLocationsByDeviceId_Success() {
            List<LocationData> locations = Arrays.asList(validLocation);
            when(locationRepository.findByDeviceIdOrderByTimestampDesc("ESP32-001"))
                    .thenReturn(locations);

            List<LocationData> result = locationService.getLocationsByDeviceId("ESP32-001");

            assertNotNull(result);
            assertEquals(1, result.size());
            assertEquals("ESP32-001", result.get(0).getDeviceId());
            verify(locationRepository, times(1))
                    .findByDeviceIdOrderByTimestampDesc("ESP32-001");
        }

        @Test
        @DisplayName("エッジケース: 該当するデバイスIDがない場合空リストを返す")
        void testGetLocationsByDeviceId_NotFound() {
            when(locationRepository.findByDeviceIdOrderByTimestampDesc("UNKNOWN"))
                    .thenReturn(Collections.emptyList());

            List<LocationData> result = locationService.getLocationsByDeviceId("UNKNOWN");

            assertNotNull(result);
            assertTrue(result.isEmpty());
        }

        @Test
        @DisplayName("正常系: 同一デバイスの複数位置情報を取得できる")
        void testGetLocationsByDeviceId_MultipleLocations() {
            LocationData location2 = LocationData.builder()
                    .id(2L)
                    .deviceId("ESP32-001")
                    .latitude(35.681236)
                    .longitude(139.767125)
                    .timestamp(testTime.plusMinutes(10))
                    .build();

            List<LocationData> locations = Arrays.asList(location2, validLocation);
            when(locationRepository.findByDeviceIdOrderByTimestampDesc("ESP32-001"))
                    .thenReturn(locations);

            List<LocationData> result = locationService.getLocationsByDeviceId("ESP32-001");

            assertEquals(2, result.size());
            // タイムスタンプ降順で返されることを確認
            assertTrue(result.get(0).getTimestamp().isAfter(result.get(1).getTimestamp()));
        }
    }

    /**
     * getLocationById のテスト
     */
    @Nested
    @DisplayName("ID指定位置情報取得")
    class GetLocationByIdTests {

        @Test
        @DisplayName("正常系: 存在するIDで位置情報を取得できる")
        void testGetLocationById_Success() {
            when(locationRepository.findById(1L)).thenReturn(Optional.of(validLocation));

            Optional<LocationData> result = locationService.getLocationById(1L);

            assertTrue(result.isPresent());
            assertEquals("ESP32-001", result.get().getDeviceId());
            verify(locationRepository, times(1)).findById(1L);
        }

        @Test
        @DisplayName("異常系: 存在しないIDの場合空のOptionalを返す")
        void testGetLocationById_NotFound() {
            when(locationRepository.findById(999L)).thenReturn(Optional.empty());

            Optional<LocationData> result = locationService.getLocationById(999L);

            assertFalse(result.isPresent());
            verify(locationRepository, times(1)).findById(999L);
        }

        @Test
        @DisplayName("境界値: ID=0で検索した場合")
        void testGetLocationById_ZeroId() {
            when(locationRepository.findById(0L)).thenReturn(Optional.empty());

            Optional<LocationData> result = locationService.getLocationById(0L);

            assertFalse(result.isPresent());
        }

        @Test
        @DisplayName("境界値: 最大Long値のIDで検索した場合")
        void testGetLocationById_MaxLongId() {
            when(locationRepository.findById(Long.MAX_VALUE)).thenReturn(Optional.empty());

            Optional<LocationData> result = locationService.getLocationById(Long.MAX_VALUE);

            assertFalse(result.isPresent());
        }
    }

    /**
     * deleteLocation のテスト
     */
    @Nested
    @DisplayName("位置情報削除")
    class DeleteLocationTests {

        @Test
        @DisplayName("正常系: 存在するIDの位置情報を削除できる")
        void testDeleteLocation_Success() {
            when(locationRepository.existsById(1L)).thenReturn(true);

            boolean result = locationService.deleteLocation(1L);

            assertTrue(result);
            verify(locationRepository, times(1)).existsById(1L);
            verify(locationRepository, times(1)).deleteById(1L);
        }

        @Test
        @DisplayName("異常系: 存在しないIDの場合falseを返す")
        void testDeleteLocation_NotFound() {
            when(locationRepository.existsById(999L)).thenReturn(false);

            boolean result = locationService.deleteLocation(999L);

            assertFalse(result);
            verify(locationRepository, times(1)).existsById(999L);
            verify(locationRepository, never()).deleteById(999L);
        }

        @Test
        @DisplayName("境界値: ID=0の削除を試みた場合")
        void testDeleteLocation_ZeroId() {
            when(locationRepository.existsById(0L)).thenReturn(false);

            boolean result = locationService.deleteLocation(0L);

            assertFalse(result);
            verify(locationRepository, never()).deleteById(0L);
        }
    }

    /**
     * getDeviceCount のテスト
     */
    @Nested
    @DisplayName("デバイス数取得")
    class GetDeviceCountTests {

        @Test
        @DisplayName("正常系: デバイス数を取得できる")
        void testGetDeviceCount_Success() {
            when(locationRepository.countDistinctDevices()).thenReturn(5L);

            long count = locationService.getDeviceCount();

            assertEquals(5L, count);
            verify(locationRepository, times(1)).countDistinctDevices();
        }

        @Test
        @DisplayName("エッジケース: デバイスが0件の場合0を返す")
        void testGetDeviceCount_Zero() {
            when(locationRepository.countDistinctDevices()).thenReturn(0L);

            long count = locationService.getDeviceCount();

            assertEquals(0L, count);
        }

        @Test
        @DisplayName("境界値: 大量のデバイスが存在する場合")
        void testGetDeviceCount_LargeNumber() {
            when(locationRepository.countDistinctDevices()).thenReturn(10000L);

            long count = locationService.getDeviceCount();

            assertEquals(10000L, count);
        }
    }

    /**
     * getRecentLocations のテスト
     */
    @Nested
    @DisplayName("最新位置情報取得")
    class GetRecentLocationsTests {

        @Test
        @DisplayName("正常系: 最新の位置情報を取得できる")
        void testGetRecentLocations_Success() {
            List<LocationData> locations = Arrays.asList(validLocation);
            when(locationRepository.findTop50ByOrderByTimestampDesc()).thenReturn(locations);

            List<LocationData> result = locationService.getRecentLocations();

            assertNotNull(result);
            assertEquals(1, result.size());
            verify(locationRepository, times(1)).findTop50ByOrderByTimestampDesc();
        }

        @Test
        @DisplayName("エッジケース: データが0件の場合空リストを返す")
        void testGetRecentLocations_EmptyList() {
            when(locationRepository.findTop50ByOrderByTimestampDesc())
                    .thenReturn(Collections.emptyList());

            List<LocationData> result = locationService.getRecentLocations();

            assertNotNull(result);
            assertTrue(result.isEmpty());
        }
    }

    /**
     * getLatestLocationByDeviceId のテスト
     */
    @Nested
    @DisplayName("デバイス最新位置情報取得")
    class GetLatestLocationByDeviceIdTests {

        @Test
        @DisplayName("正常系: デバイスの最新位置情報を取得できる")
        void testGetLatestLocationByDeviceId_Success() {
            when(locationRepository.findLatestByDeviceId("ESP32-001"))
                    .thenReturn(Optional.of(validLocation));

            Optional<LocationData> result = locationService
                    .getLatestLocationByDeviceId("ESP32-001");

            assertTrue(result.isPresent());
            assertEquals("ESP32-001", result.get().getDeviceId());
        }

        @Test
        @DisplayName("異常系: 該当するデバイスIDがない場合空のOptionalを返す")
        void testGetLatestLocationByDeviceId_NotFound() {
            when(locationRepository.findLatestByDeviceId("UNKNOWN"))
                    .thenReturn(Optional.empty());

            Optional<LocationData> result = locationService
                    .getLatestLocationByDeviceId("UNKNOWN");

            assertFalse(result.isPresent());
        }
    }

    /**
     * getLocationsByTimeRange のテスト
     */
    @Nested
    @DisplayName("期間指定位置情報取得")
    class GetLocationsByTimeRangeTests {

        @Test
        @DisplayName("正常系: 指定期間内の位置情報を取得できる")
        void testGetLocationsByTimeRange_Success() {
            LocalDateTime startTime = testTime.minusHours(1);
            LocalDateTime endTime = testTime.plusHours(1);
            List<LocationData> locations = Arrays.asList(validLocation);

            when(locationRepository.findByTimestampBetween(startTime, endTime))
                    .thenReturn(locations);

            List<LocationData> result = locationService
                    .getLocationsByTimeRange(startTime, endTime);

            assertNotNull(result);
            assertEquals(1, result.size());
        }

        @Test
        @DisplayName("エッジケース: 該当する期間のデータがない場合空リストを返す")
        void testGetLocationsByTimeRange_NoData() {
            LocalDateTime startTime = testTime.plusDays(1);
            LocalDateTime endTime = testTime.plusDays(2);

            when(locationRepository.findByTimestampBetween(startTime, endTime))
                    .thenReturn(Collections.emptyList());

            List<LocationData> result = locationService
                    .getLocationsByTimeRange(startTime, endTime);

            assertNotNull(result);
            assertTrue(result.isEmpty());
        }

        @Test
        @DisplayName("境界値: 開始時刻と終了時刻が同じ場合")
        void testGetLocationsByTimeRange_SameTime() {
            when(locationRepository.findByTimestampBetween(testTime, testTime))
                    .thenReturn(Collections.emptyList());

            List<LocationData> result = locationService
                    .getLocationsByTimeRange(testTime, testTime);

            assertNotNull(result);
        }
    }
}
