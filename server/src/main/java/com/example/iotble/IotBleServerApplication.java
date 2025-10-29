package com.example.iotble;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * IoT BLE位置情報トラッキングシステムのメインアプリケーションクラス
 * 
 * このアプリケーションは以下の機能を提供します
 * - BLEデバイスからの位置情報の受信
 * - 位置情報のデータベース保存
 * - REST APIによる位置情報の提供
 * - Webインターフェースによる可視化
 */
@SpringBootApplication
public class IotBleServerApplication {

    /**
     * アプリケーションのエントリーポイント
     * 
     * @param args コマンドライン引数
     */
    public static void main(String[] args) {
        SpringApplication.run(IotBleServerApplication.class, args);
        System.out.println("=================================================");
        System.out.println("IoT BLE Location Server が起動しました");
        System.out.println("Web UI: http://localhost:8080");
        System.out.println("API Endpoint: http://localhost:8080/api/locations");
        System.out.println("=================================================");
    }
}
