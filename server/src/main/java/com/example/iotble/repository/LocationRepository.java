package com.example.iotble.repository;

import com.example.iotble.model.LocationData;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * 位置情報データのリポジトリインターフェース
 * 
 * データベースへのCRUD操作とカスタムクエリを提供します
 */
@Repository
public interface LocationRepository extends JpaRepository<LocationData, Long> {

    /**
     * デバイスIDで位置情報を検索
     * 
     * @param deviceId デバイスID
     * @return 該当する位置情報のリスト（タイムスタンプ降順）
     */
    List<LocationData> findByDeviceIdOrderByTimestampDesc(String deviceId);

    /**
     * デバイスIDの最新の位置情報を取得
     * 
     * @param deviceId デバイスID
     * @return 最新の位置情報（存在する場合）
     */
    @Query("SELECT l FROM LocationData l WHERE l.deviceId = :deviceId " +
           "ORDER BY l.timestamp DESC LIMIT 1")
    Optional<LocationData> findLatestByDeviceId(@Param("deviceId") String deviceId);

    /**
     * 指定期間内の位置情報を取得
     * 
     * @param startTime 開始時刻
     * @param endTime 終了時刻
     * @return 該当する位置情報のリスト（タイムスタンプ降順）
     */
    @Query("SELECT l FROM LocationData l WHERE l.timestamp BETWEEN :startTime AND :endTime " +
           "ORDER BY l.timestamp DESC")
    List<LocationData> findByTimestampBetween(
            @Param("startTime") LocalDateTime startTime,
            @Param("endTime") LocalDateTime endTime);

    /**
     * 最新N件の位置情報を取得
     * 
     * @return 最新の位置情報リスト
     */
    @Query("SELECT l FROM LocationData l ORDER BY l.timestamp DESC LIMIT 50")
    List<LocationData> findTop50ByOrderByTimestampDesc();

    /**
     * デバイスの総数を取得
     * 
     * @return 登録されているデバイスの総数
     */
    @Query("SELECT COUNT(DISTINCT l.deviceId) FROM LocationData l")
    long countDistinctDevices();
}
