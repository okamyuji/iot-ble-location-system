package com.example.iotble.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Objects;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.iotble.model.LocationData;
import com.example.iotble.repository.LocationRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * 位置情報サービスの実装クラス
 * 
 * ビジネスロジックとデータアクセスを管理します
 */
@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class LocationServiceImpl implements LocationService {

    private final LocationRepository locationRepository;

    /**
     * 新しい位置情報を保存
     * 
     * @param locationData 位置情報データ
     * @return 保存された位置情報
     */
    @Override
    public LocationData saveLocation(LocationData locationData) {
        // タイムスタンプが設定されていない場合は現在時刻を設定
        if (locationData.getTimestamp() == null) {
            locationData.setTimestamp(LocalDateTime.now());
        }

        LocationData saved = locationRepository.save(locationData);
        log.info("位置情報を保存しました: {}", saved);

        return saved;
    }

    /**
     * すべての位置情報を取得
     * 
     * @return すべての位置情報のリスト
     */
    @Override
    @Transactional(readOnly = true)
    public List<LocationData> getAllLocations() {
        return locationRepository.findAll();
    }

    /**
     * 最新50件の位置情報を取得
     * 
     * @return 最新の位置情報リスト
     */
    @Override
    @Transactional(readOnly = true)
    public List<LocationData> getRecentLocations() {
        return locationRepository.findTop50ByOrderByTimestampDesc();
    }

    /**
     * デバイスIDで位置情報を取得
     * 
     * @param deviceId デバイスID
     * @return 該当する位置情報のリスト
     */
    @Override
    @Transactional(readOnly = true)
    public List<LocationData> getLocationsByDeviceId(String deviceId) {
        return locationRepository.findByDeviceIdOrderByTimestampDesc(deviceId);
    }

    /**
     * デバイスの最新位置情報を取得
     * 
     * @param deviceId デバイスID
     * @return 最新の位置情報（存在する場合）
     */
    @Override
    @Transactional(readOnly = true)
    public Optional<LocationData> getLatestLocationByDeviceId(String deviceId) {
        return locationRepository.findLatestByDeviceId(deviceId);
    }

    /**
     * 指定期間内の位置情報を取得
     * 
     * @param startTime 開始時刻
     * @param endTime   終了時刻
     * @return 該当する位置情報のリスト
     */
    @Override
    @Transactional(readOnly = true)
    public List<LocationData> getLocationsByTimeRange(LocalDateTime startTime, LocalDateTime endTime) {
        return locationRepository.findByTimestampBetween(startTime, endTime);
    }

    /**
     * IDで位置情報を取得
     * 
     * @param id 位置情報ID
     * @return 位置情報（存在する場合）
     */
    @Override
    @Transactional(readOnly = true)
    public Optional<LocationData> getLocationById(Long id) {
        if (id == null) {
            return Optional.empty();
        }
        return locationRepository.findById(id);
    }

    /**
     * 登録されているデバイスの総数を取得
     * 
     * @return デバイスの総数
     */
    @Override
    @Transactional(readOnly = true)
    public long getDeviceCount() {
        return locationRepository.countDistinctDevices();
    }

    /**
     * 位置情報を削除
     * 
     * @param id 削除する位置情報のID
     * @return 削除が成功した場合true
     */
    @Override
    public boolean deleteLocation(Long id) {
        Objects.requireNonNull(id, "ID must not be null");
        if (locationRepository.existsById(id)) {
            locationRepository.deleteById(id);
            log.info("位置情報を削除しました: ID={}", id);
            return true;
        }
        log.warn("削除対象の位置情報が見つかりません: ID={}", id);
        return false;
    }

    /**
     * すべての位置情報を削除（テスト用）
     */
    @Override
    public void deleteAllLocations() {
        locationRepository.deleteAll();
        log.info("すべての位置情報を削除しました");
    }
}
