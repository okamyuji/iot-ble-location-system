package com.example.iotble.controller;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

import com.example.iotble.model.LocationData;
import com.example.iotble.service.LocationService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * 位置情報のRESTコントローラー
 * 
 * API endpoints:
 * - POST /api/locations : 新しい位置情報の登録
 * - GET /api/locations : すべての位置情報の取得
 * - GET /api/locations/recent : 最新50件の位置情報の取得
 * - GET /api/locations/{id} : 特定の位置情報の取得
 * - GET /api/locations/device/{deviceId} : デバイス別の位置情報取得
 * - DELETE /api/locations/{id} : 位置情報の削除
 * - GET /api/stats : 統計情報の取得
 * 
 * Web UI:
 * - GET / : メインページ
 */
@Controller
@RequiredArgsConstructor
@Slf4j
public class LocationController {

    private final LocationService locationService;

    /**
     * メインページの表示
     */
    @GetMapping("/")
    public String index(Model model) {
        List<LocationData> recentLocations = locationService.getRecentLocations();
        long deviceCount = locationService.getDeviceCount();

        // タイムスタンプをJSTに変換したDTOリストを作成
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
        ZoneId jst = ZoneId.of("Asia/Tokyo");

        List<Map<String, Object>> locationsWithJst = recentLocations.stream()
                .map(location -> {
                    Map<String, Object> map = new HashMap<>();
                    map.put("deviceId", location.getDeviceId());
                    map.put("latitude", location.getLatitude());
                    map.put("longitude", location.getLongitude());
                    map.put("altitude", location.getAltitude());
                    map.put("rssi", location.getRssi());
                    // UTCからJSTに変換してフォーマット
                    String jstTimestamp = location.getTimestamp()
                            .atZone(ZoneId.of("UTC"))
                            .withZoneSameInstant(jst)
                            .format(formatter);
                    map.put("timestampJst", jstTimestamp);
                    return map;
                })
                .collect(Collectors.toList());

        model.addAttribute("locations", locationsWithJst);
        model.addAttribute("deviceCount", deviceCount);
        model.addAttribute("locationCount", recentLocations.size());

        return "index";
    }

    /**
     * 新しい位置情報を登録
     * 
     * @param locationData  位置情報データ
     * @param bindingResult バリデーション結果
     * @return 保存された位置情報
     */
    @PostMapping("/api/locations")
    @ResponseBody
    public ResponseEntity<?> createLocation(
            @Valid @RequestBody LocationData locationData,
            BindingResult bindingResult) {

        if (bindingResult.hasErrors()) {
            Map<String, String> errors = new HashMap<>();
            bindingResult.getFieldErrors().forEach(error -> errors.put(error.getField(), error.getDefaultMessage()));
            log.warn("位置情報のバリデーションエラー: {}", errors);
            return ResponseEntity.badRequest().body(errors);
        }

        try {
            LocationData saved = locationService.saveLocation(locationData);
            log.info("位置情報を受信しました: デバイスID={}, 緯度={}, 経度={}",
                    saved.getDeviceId(), saved.getLatitude(), saved.getLongitude());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            log.error("位置情報の保存に失敗しました", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("error", "位置情報の保存に失敗しました: " + e.getMessage()));
        }
    }

    /**
     * すべての位置情報を取得
     * 
     * @return 位置情報のリスト
     */
    @GetMapping("/api/locations")
    @ResponseBody
    public ResponseEntity<List<LocationData>> getAllLocations() {
        List<LocationData> locations = locationService.getAllLocations();
        return ResponseEntity.ok(locations);
    }

    /**
     * 最新50件の位置情報を取得
     * 
     * @return 最新の位置情報リスト
     */
    @GetMapping("/api/locations/recent")
    @ResponseBody
    public ResponseEntity<List<LocationData>> getRecentLocations() {
        List<LocationData> locations = locationService.getRecentLocations();
        return ResponseEntity.ok(locations);
    }

    /**
     * 特定の位置情報を取得
     * 
     * @param id 位置情報ID
     * @return 位置情報（見つからない場合は404）
     */
    @GetMapping("/api/locations/{id}")
    @ResponseBody
    public ResponseEntity<?> getLocationById(@PathVariable Long id) {
        return locationService.getLocationById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * デバイスIDで位置情報を取得
     * 
     * @param deviceId デバイスID
     * @return 該当する位置情報のリスト
     */
    @GetMapping("/api/locations/device/{deviceId}")
    @ResponseBody
    public ResponseEntity<List<LocationData>> getLocationsByDevice(@PathVariable String deviceId) {
        List<LocationData> locations = locationService.getLocationsByDeviceId(deviceId);
        return ResponseEntity.ok(locations);
    }

    /**
     * デバイスの最新位置情報を取得
     * 
     * @param deviceId デバイスID
     * @return 最新の位置情報（見つからない場合は404）
     */
    @GetMapping("/api/locations/device/{deviceId}/latest")
    @ResponseBody
    public ResponseEntity<?> getLatestLocationByDevice(@PathVariable String deviceId) {
        return locationService.getLatestLocationByDeviceId(deviceId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * 期間指定で位置情報を取得
     * 
     * @param startTime 開始時刻
     * @param endTime   終了時刻
     * @return 該当する位置情報のリスト
     */
    @GetMapping("/api/locations/range")
    @ResponseBody
    public ResponseEntity<List<LocationData>> getLocationsByTimeRange(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime startTime,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime endTime) {

        List<LocationData> locations = locationService.getLocationsByTimeRange(startTime, endTime);
        return ResponseEntity.ok(locations);
    }

    /**
     * 位置情報を削除
     * 
     * @param id 削除する位置情報のID
     * @return 削除結果
     */
    @DeleteMapping("/api/locations/{id}")
    @ResponseBody
    public ResponseEntity<?> deleteLocation(@PathVariable Long id) {
        boolean deleted = locationService.deleteLocation(id);
        if (deleted) {
            return ResponseEntity.ok(Map.of("message", "位置情報を削除しました"));
        } else {
            return ResponseEntity.notFound().build();
        }
    }

    /**
     * 統計情報を取得
     * 
     * @return 統計情報
     */
    @GetMapping("/api/stats")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> getStats() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("totalLocations", locationService.getAllLocations().size());
        stats.put("deviceCount", locationService.getDeviceCount());
        stats.put("timestamp", LocalDateTime.now());

        return ResponseEntity.ok(stats);
    }
}
