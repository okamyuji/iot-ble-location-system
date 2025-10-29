package com.example.iotble.repository;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;

import com.example.iotble.model.LocationData;

/**
 * LocationRepositoryのユニットテスト
 * 
 * 正常系、異常系、境界値、エッジケースを網羅的にテストします
 */
@DataJpaTest
@DisplayName("LocationRepository テスト")
class LocationRepositoryTest {

    @Autowired
    private TestEntityManager entityManager;

    @Autowired
    private LocationRepository locationRepository;

    private LocalDateTime testTime;

    /**
     * 各テスト実行前の初期化処理
     */
    @BeforeEach
    void setUp() {
        testTime = LocalDateTime.of(2025, 1, 1, 12, 0, 0);
        // 各テストで必要なデータは個別に作成
    }

    /**
     * findByDeviceIdOrderByTimestampDesc のテスト
     */
    @Nested
    @DisplayName("デバイスID検索（タイムスタンプ降順）")
    class FindByDeviceIdTests {

        @Test
        @DisplayName("正常系: デバイスIDで位置情報を検索できる")
        void testFindByDeviceId_Success() {
            createAndPersistLocation("ESP32-001", 35.658581, 139.745433, testTime);

            List<LocationData> locations = locationRepository
                    .findByDeviceIdOrderByTimestampDesc("ESP32-001");

            assertNotNull(locations);
            assertEquals(1, locations.size());
            assertEquals("ESP32-001", locations.get(0).getDeviceId());
        }

        @Test
        @DisplayName("正常系: 複数の位置情報がタイムスタンプ降順で返される")
        void testFindByDeviceId_OrderByTimestampDesc() {
            createAndPersistLocation("ESP32-001", 35.658581, 139.745433, testTime);
            createAndPersistLocation("ESP32-001", 35.681236, 139.767125,
                    testTime.plusMinutes(10));
            createAndPersistLocation("ESP32-001", 35.689487, 139.691711,
                    testTime.plusMinutes(20));

            List<LocationData> locations = locationRepository
                    .findByDeviceIdOrderByTimestampDesc("ESP32-001");

            assertEquals(3, locations.size());
            // 降順であることを確認
            assertTrue(locations.get(0).getTimestamp().isAfter(locations.get(1).getTimestamp()));
            assertTrue(locations.get(1).getTimestamp().isAfter(locations.get(2).getTimestamp()));
        }

        @Test
        @DisplayName("エッジケース: 存在しないデバイスIDの場合空リストを返す")
        void testFindByDeviceId_NotFound() {
            List<LocationData> locations = locationRepository
                    .findByDeviceIdOrderByTimestampDesc("UNKNOWN");

            assertNotNull(locations);
            assertTrue(locations.isEmpty());
        }

        @Test
        @DisplayName("正常系: 他のデバイスのデータは含まれない")
        void testFindByDeviceId_FiltersByDeviceId() {
            createAndPersistLocation("ESP32-001", 35.658581, 139.745433, testTime);
            createAndPersistLocation("ESP32-002", 35.681236, 139.767125, testTime);

            List<LocationData> locations = locationRepository
                    .findByDeviceIdOrderByTimestampDesc("ESP32-001");

            assertEquals(1, locations.size());
            assertEquals("ESP32-001", locations.get(0).getDeviceId());
        }
    }

    /**
     * findLatestByDeviceId のテスト
     */
    @Nested
    @DisplayName("デバイス最新位置情報取得")
    class FindLatestByDeviceIdTests {

        @Test
        @DisplayName("正常系: デバイスの最新位置情報を取得できる")
        void testFindLatestByDeviceId_Success() {
            createAndPersistLocation("ESP32-001", 35.658581, 139.745433, testTime);
            LocationData latest = createAndPersistLocation("ESP32-001", 35.681236, 139.767125,
                    testTime.plusMinutes(10));

            Optional<LocationData> result = locationRepository.findLatestByDeviceId("ESP32-001");

            assertTrue(result.isPresent());
            assertEquals(latest.getId(), result.get().getId());
            assertEquals(35.681236, result.get().getLatitude(), 0.000001);
        }

        @Test
        @DisplayName("エッジケース: 存在しないデバイスIDの場合空のOptionalを返す")
        void testFindLatestByDeviceId_NotFound() {
            Optional<LocationData> result = locationRepository.findLatestByDeviceId("UNKNOWN");

            assertFalse(result.isPresent());
        }

        @Test
        @DisplayName("正常系: 複数データがある場合最新のみ返す")
        void testFindLatestByDeviceId_ReturnsOnlyLatest() {
            createAndPersistLocation("ESP32-001", 35.658581, 139.745433, testTime);
            createAndPersistLocation("ESP32-001", 35.681236, 139.767125, testTime.plusMinutes(10));
            LocationData latest = createAndPersistLocation("ESP32-001", 35.689487, 139.691711,
                    testTime.plusMinutes(20));

            Optional<LocationData> result = locationRepository.findLatestByDeviceId("ESP32-001");

            assertTrue(result.isPresent());
            assertEquals(latest.getId(), result.get().getId());
        }
    }

    /**
     * countDistinctDevices のテスト
     */
    @Nested
    @DisplayName("デバイス数カウント")
    class CountDistinctDevicesTests {

        @Test
        @DisplayName("正常系: デバイス数を正しくカウントできる")
        void testCountDistinctDevices_Success() {
            createAndPersistLocation("ESP32-001", 35.658581, 139.745433, testTime);
            createAndPersistLocation("ESP32-002", 35.681236, 139.767125, testTime);

            long count = locationRepository.countDistinctDevices();

            assertEquals(2L, count);
        }

        @Test
        @DisplayName("正常系: 同一デバイスの複数データは1としてカウントされる")
        void testCountDistinctDevices_SameDevice() {
            createAndPersistLocation("ESP32-001", 35.658581, 139.745433, testTime);
            createAndPersistLocation("ESP32-001", 35.681236, 139.767125, testTime.plusMinutes(10));
            createAndPersistLocation("ESP32-002", 35.689487, 139.691711, testTime);

            long count = locationRepository.countDistinctDevices();

            assertEquals(2L, count);
        }

        @Test
        @DisplayName("エッジケース: データが0件の場合0を返す")
        void testCountDistinctDevices_Zero() {
            long count = locationRepository.countDistinctDevices();

            assertEquals(0L, count);
        }

        @Test
        @DisplayName("境界値: 多数のデバイスが存在する場合")
        void testCountDistinctDevices_ManyDevices() {
            for (int i = 1; i <= 100; i++) {
                createAndPersistLocation("ESP32-" + String.format("%03d", i), 35.0, 139.0, testTime);
            }

            long count = locationRepository.countDistinctDevices();

            assertEquals(100L, count);
        }
    }

    /**
     * save と findById のテスト
     */
    @Nested
    @DisplayName("保存と検索")
    class SaveAndFindByIdTests {

        @Test
        @DisplayName("正常系: 位置情報を保存して検索できる")
        void testSaveAndFindById_Success() {
            LocationData newLocation = LocationData.builder()
                    .deviceId("ESP32-003")
                    .latitude(35.689487)
                    .longitude(139.691711)
                    .timestamp(testTime)
                    .build();

            LocationData saved = locationRepository.save(newLocation);
            Optional<LocationData> found = locationRepository.findById(saved.getId());

            assertTrue(found.isPresent());
            assertEquals("ESP32-003", found.get().getDeviceId());
            assertEquals(35.689487, found.get().getLatitude(), 0.000001);
            assertEquals(139.691711, found.get().getLongitude(), 0.000001);
        }

        @Test
        @DisplayName("境界値: 緯度-90.0の位置情報を保存できる")
        void testSave_MinLatitude() {
            LocationData location = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(-90.0)
                    .longitude(0.0)
                    .timestamp(testTime)
                    .build();

            LocationData saved = locationRepository.save(location);

            assertEquals(-90.0, saved.getLatitude());
        }

        @Test
        @DisplayName("境界値: 緯度90.0の位置情報を保存できる")
        void testSave_MaxLatitude() {
            LocationData location = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(90.0)
                    .longitude(0.0)
                    .timestamp(testTime)
                    .build();

            LocationData saved = locationRepository.save(location);

            assertEquals(90.0, saved.getLatitude());
        }

        @Test
        @DisplayName("境界値: 経度-180.0の位置情報を保存できる")
        void testSave_MinLongitude() {
            LocationData location = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(0.0)
                    .longitude(-180.0)
                    .timestamp(testTime)
                    .build();

            LocationData saved = locationRepository.save(location);

            assertEquals(-180.0, saved.getLongitude());
        }

        @Test
        @DisplayName("境界値: 経度180.0の位置情報を保存できる")
        void testSave_MaxLongitude() {
            LocationData location = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(0.0)
                    .longitude(180.0)
                    .timestamp(testTime)
                    .build();

            LocationData saved = locationRepository.save(location);

            assertEquals(180.0, saved.getLongitude());
        }

        @Test
        @DisplayName("エッジケース: オプション項目がnullでも保存できる")
        void testSave_OptionalFieldsNull() {
            LocationData location = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(35.658581)
                    .longitude(139.745433)
                    .timestamp(testTime)
                    .build();

            LocationData saved = locationRepository.save(location);
            Optional<LocationData> found = locationRepository.findById(saved.getId());

            assertTrue(found.isPresent());
            assertNull(found.get().getAltitude());
            assertNull(found.get().getAccuracy());
            assertNull(found.get().getRssi());
        }

        @Test
        @DisplayName("正常系: 全てのフィールドを含む位置情報を保存できる")
        void testSave_AllFields() {
            LocationData location = LocationData.builder()
                    .deviceId("ESP32-001")
                    .latitude(35.658581)
                    .longitude(139.745433)
                    .altitude(100.5)
                    .accuracy(5.0)
                    .rssi(-65)
                    .timestamp(testTime)
                    .build();

            LocationData saved = locationRepository.save(location);
            Optional<LocationData> found = locationRepository.findById(saved.getId());

            assertTrue(found.isPresent());
            assertEquals(100.5, found.get().getAltitude());
            assertEquals(5.0, found.get().getAccuracy());
            assertEquals(-65, found.get().getRssi());
        }

        @Test
        @DisplayName("異常系: 存在しないIDで検索した場合空のOptionalを返す")
        void testFindById_NotFound() {
            Optional<LocationData> found = locationRepository.findById(999L);

            assertFalse(found.isPresent());
        }
    }

    /**
     * deleteById のテスト
     */
    @Nested
    @DisplayName("削除")
    class DeleteByIdTests {

        @Test
        @DisplayName("正常系: 位置情報を削除できる")
        void testDeleteById_Success() {
            LocationData location = createAndPersistLocation("ESP32-001", 35.658581, 139.745433, testTime);
            Long id = location.getId();

            locationRepository.deleteById(id);
            Optional<LocationData> found = locationRepository.findById(id);

            assertFalse(found.isPresent());
        }

        @Test
        @DisplayName("正常系: 削除しても他のデータは残る")
        void testDeleteById_OtherDataRemains() {
            LocationData location1 = createAndPersistLocation("ESP32-001", 35.658581, 139.745433, testTime);
            LocationData location2 = createAndPersistLocation("ESP32-002", 35.681236, 139.767125, testTime);

            locationRepository.deleteById(location1.getId());

            Optional<LocationData> found1 = locationRepository.findById(location1.getId());
            Optional<LocationData> found2 = locationRepository.findById(location2.getId());

            assertFalse(found1.isPresent());
            assertTrue(found2.isPresent());
        }

        @Test
        @DisplayName("エッジケース: 存在しないIDの削除を試みてもエラーにならない")
        void testDeleteById_NotFound() {
            assertDoesNotThrow(() -> locationRepository.deleteById(999L));
        }
    }

    /**
     * findByTimestampBetween のテスト
     */
    @Nested
    @DisplayName("期間指定検索")
    class FindByTimestampBetweenTests {

        @Test
        @DisplayName("正常系: 指定期間内の位置情報を取得できる")
        void testFindByTimestampBetween_Success() {
            createAndPersistLocation("ESP32-001", 35.658581, 139.745433, testTime);
            createAndPersistLocation("ESP32-001", 35.681236, 139.767125, testTime.plusHours(1));
            createAndPersistLocation("ESP32-001", 35.689487, 139.691711, testTime.plusHours(2));

            LocalDateTime startTime = testTime.minusMinutes(30);
            LocalDateTime endTime = testTime.plusHours(1).plusMinutes(30);

            List<LocationData> locations = locationRepository
                    .findByTimestampBetween(startTime, endTime);

            assertEquals(2, locations.size());
        }

        @Test
        @DisplayName("エッジケース: 該当する期間のデータがない場合空リストを返す")
        void testFindByTimestampBetween_NoData() {
            createAndPersistLocation("ESP32-001", 35.658581, 139.745433, testTime);

            LocalDateTime startTime = testTime.plusDays(1);
            LocalDateTime endTime = testTime.plusDays(2);

            List<LocationData> locations = locationRepository
                    .findByTimestampBetween(startTime, endTime);

            assertTrue(locations.isEmpty());
        }

        @Test
        @DisplayName("境界値: 開始時刻と終了時刻が同じ場合")
        void testFindByTimestampBetween_SameTime() {
            createAndPersistLocation("ESP32-001", 35.658581, 139.745433, testTime);

            List<LocationData> locations = locationRepository
                    .findByTimestampBetween(testTime, testTime);

            // BETWEENは境界を含むため、1件取得できる
            assertEquals(1, locations.size());
        }

        @Test
        @DisplayName("正常系: タイムスタンプ降順で返される")
        void testFindByTimestampBetween_OrderByTimestampDesc() {
            createAndPersistLocation("ESP32-001", 35.658581, 139.745433, testTime);
            createAndPersistLocation("ESP32-001", 35.681236, 139.767125, testTime.plusHours(1));

            List<LocationData> locations = locationRepository
                    .findByTimestampBetween(testTime.minusHours(1), testTime.plusHours(2));

            assertEquals(2, locations.size());
            assertTrue(locations.get(0).getTimestamp().isAfter(locations.get(1).getTimestamp()));
        }
    }

    /**
     * findTop50ByOrderByTimestampDesc のテスト
     */
    @Nested
    @DisplayName("最新50件取得")
    class FindTop50Tests {

        @Test
        @DisplayName("正常系: 最新50件を取得できる")
        void testFindTop50_Success() {
            createAndPersistLocation("ESP32-001", 35.658581, 139.745433, testTime);
            createAndPersistLocation("ESP32-001", 35.681236, 139.767125, testTime.plusMinutes(10));

            List<LocationData> locations = locationRepository.findTop50ByOrderByTimestampDesc();

            assertEquals(2, locations.size());
            assertTrue(locations.get(0).getTimestamp().isAfter(locations.get(1).getTimestamp()));
        }

        @Test
        @DisplayName("境界値: 50件を超えるデータがある場合50件のみ返す")
        void testFindTop50_LimitTo50() {
            for (int i = 0; i < 60; i++) {
                createAndPersistLocation("ESP32-001", 35.0, 139.0, testTime.plusMinutes(i));
            }

            List<LocationData> locations = locationRepository.findTop50ByOrderByTimestampDesc();

            assertEquals(50, locations.size());
        }

        @Test
        @DisplayName("エッジケース: データが0件の場合空リストを返す")
        void testFindTop50_EmptyList() {
            List<LocationData> locations = locationRepository.findTop50ByOrderByTimestampDesc();

            assertTrue(locations.isEmpty());
        }

        @Test
        @DisplayName("正常系: タイムスタンプ降順で返される")
        void testFindTop50_OrderByTimestampDesc() {
            for (int i = 0; i < 10; i++) {
                createAndPersistLocation("ESP32-001", 35.0, 139.0, testTime.plusMinutes(i));
            }

            List<LocationData> locations = locationRepository.findTop50ByOrderByTimestampDesc();

            for (int i = 0; i < locations.size() - 1; i++) {
                assertTrue(locations.get(i).getTimestamp()
                        .isAfter(locations.get(i + 1).getTimestamp()));
            }
        }
    }

    /**
     * ヘルパーメソッド: 位置情報を作成して永続化
     */
    private LocationData createAndPersistLocation(String deviceId, double latitude,
            double longitude, LocalDateTime timestamp) {
        LocationData location = LocationData.builder()
                .deviceId(deviceId)
                .latitude(latitude)
                .longitude(longitude)
                .timestamp(timestamp)
                .build();
        entityManager.persist(location);
        entityManager.flush();
        return location;
    }
}
