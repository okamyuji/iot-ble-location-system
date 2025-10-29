package com.example.iotble.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import com.example.iotble.model.LocationData;

/**
 * 位置情報サービスのインターフェース
 * 
 * ビジネスロジックとデータアクセスを管理します
 */
public interface LocationService {

    /**
     * 新しい位置情報を保存
     * 
     * @param locationData 位置情報データ
     * @return 保存された位置情報
     */
    LocationData saveLocation(LocationData locationData);

    /**
     * すべての位置情報を取得
     * 
     * @return すべての位置情報のリスト
     */
    List<LocationData> getAllLocations();

    /**
     * 最新50件の位置情報を取得
     * 
     * @return 最新の位置情報リスト
     */
    List<LocationData> getRecentLocations();

    /**
     * デバイスIDで位置情報を取得
     * 
     * @param deviceId デバイスID
     * @return 該当する位置情報のリスト
     */
    List<LocationData> getLocationsByDeviceId(String deviceId);

    /**
     * デバイスの最新位置情報を取得
     * 
     * @param deviceId デバイスID
     * @return 最新の位置情報（存在する場合）
     */
    Optional<LocationData> getLatestLocationByDeviceId(String deviceId);

    /**
     * 指定期間内の位置情報を取得
     * 
     * @param startTime 開始時刻
     * @param endTime   終了時刻
     * @return 該当する位置情報のリスト
     */
    List<LocationData> getLocationsByTimeRange(LocalDateTime startTime, LocalDateTime endTime);

    /**
     * IDで位置情報を取得
     * 
     * @param id 位置情報ID
     * @return 位置情報（存在する場合）
     */
    Optional<LocationData> getLocationById(Long id);

    /**
     * 登録されているデバイスの総数を取得
     * 
     * @return デバイスの総数
     */
    long getDeviceCount();

    /**
     * 位置情報を削除
     * 
     * @param id 削除する位置情報のID
     * @return 削除が成功した場合true
     */
    boolean deleteLocation(Long id);

    /**
     * すべての位置情報を削除（テスト用）
     */
    void deleteAllLocations();
}
