#!/bin/bash
# SETUP MEDIA DIRS V2 - Chuẩn cấu trúc Unified Paths

# Danh sách các ổ cứng cần tạo (Thêm đường dẫn mới vào đây nếu có ổ mới)
TARGET_DIRS=(
    "/home/cuong/Data/Torrents"
    "/mnt/external"
    "/mnt/external2"
)

for BASE_DIR in "${TARGET_DIRS[@]}"; do
    if [ -d "$BASE_DIR" ]; then
        echo ">>> Đang xử lý: $BASE_DIR"

        # 1. Tạo cấu trúc chuẩn: Phim -> Thể loại
        mkdir -p "$BASE_DIR/Movies/Live_Action"
        mkdir -p "$BASE_DIR/Movies/Animated"
        mkdir -p "$BASE_DIR/Movies/Anime"

        mkdir -p "$BASE_DIR/TV_Shows/Live_Action"
        mkdir -p "$BASE_DIR/TV_Shows/Animated"
        mkdir -p "$BASE_DIR/TV_Shows/Anime"

        # 2. Cấp quyền chuẩn (User 1000, Group 1000, Permission 775)
        chown -R 1000:1000 "$BASE_DIR"
        chmod -R 775 "$BASE_DIR"
        
        # 3. Set Sticky Bit (File mới tạo tự động thuộc về Group 1000)
        # Chỉ chạy lệnh này nếu ổ cứng là Ext4 (Linux). NTFS sẽ báo lỗi nhưng không sao.
        find "$BASE_DIR" -type d -exec chmod g+s {} + 2>/dev/null

        echo "    -> Xong!"
    else
        echo "!!! Không tìm thấy đường dẫn: $BASE_DIR (Bỏ qua)"
    fi
done

echo ">>> HOÀN TẤT TOÀN BỘ!"