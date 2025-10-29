package com.example.iotble.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 位置情報データのエンティティクラス
 * 
 * BLEデバイスから取得した位置情報を表現します
 */
@Entity
@Table(name = "location_data", indexes = {
    @Index(name = "idx_device_id", columnList = "deviceId"),
    @Index(name = "idx_timestamp", columnList = "timestamp")
})
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LocationData {

    /** 一意識別子（自動生成） */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** デバイスID（BLEデバイスの一意識別子） */
    @NotBlank(message = "デバイスIDは必須です")
    @Column(nullable = false, length = 100)
    private String deviceId;

    /** 緯度（-90.0 ~ 90.0） */
    @NotNull(message = "緯度は必須です")
    @Column(nullable = false)
    private Double latitude;

    /** 経度（-180.0 ~ 180.0） */
    @NotNull(message = "経度は必須です")
    @Column(nullable = false)
    private Double longitude;

    /** 高度（メートル、オプション） */
    @Column
    private Double altitude;

    /** 精度（メートル、オプション） */
    @Column
    private Double accuracy;

    /** BLE信号強度（dBm、オプション） */
    @Column
    private Integer rssi;

    /** タイムスタンプ（データ受信時刻） */
    @Column(nullable = false)
    private LocalDateTime timestamp;

    /** 作成日時（自動設定） */
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    /**
     * エンティティ保存前の自動処理
     */
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        if (timestamp == null) {
            timestamp = LocalDateTime.now();
        }
    }

    /**
     * 位置情報の簡易文字列表現を返す
     */
    @Override
    public String toString() {
        return String.format("LocationData[id=%d, device=%s, lat=%.6f, lon=%.6f, time=%s]",
                id, deviceId, latitude, longitude, timestamp);
    }
}
