#!/bin/sh
# ============================================================
#  蜂助手 S1 CPE 去云控改造 - 一键安装脚本
#  https://gitee.com/zzt718/fzs1-decloud
# ============================================================
#
#  【用法】在设备的「系统命令行」里粘贴这一行（约 100 字符）：
#
#    cd /tmp && curl -k -sL -o i.sh https://gitee.com/zzt718/fzs1-decloud/raw/master/install.sh && sh i.sh
#
#  【注意】原厂系统没有「系统命令行」菜单，需用直链打开：
#
#    http://192.168.1.1/SysCommand.htm
#
#  （80 后台账号密码均为 admin；登录后直接访问上面的网址即可）
#
#  【本脚本会】
#    1. 检查环境（是否为本设备、空间是否足够）
#    2. 下载最小安装包并校验 md5
#    3. 备份原包到 /usr/aos/package.bak
#    4. 替换 /usr/aos/package.tar.gz
#    5. 重启设备
#
#  【安全性】md5 不匹配则中止，不会覆盖任何文件。
# ============================================================

PKG_URL="https://gitee.com/zzt718/fzs1-decloud/raw/master/package-slim.tar.gz"
PKG_MD5="6281e2b1d6b3ac15753ff7c4820a1ed3"
PKG_SIZE="1272735"
TARGET="/usr/aos/package.tar.gz"
BACKUP="/usr/aos/package.bak"
TMP="/tmp/decloud_pkg.tar.gz"
FACTORY="/mnt/mtdblock5/usr/aos/package.tar.gz"

say()  { echo "[decloud] $1"; }
fail() { echo ""; echo "[decloud] ✗ 错误：$1"; echo "[decloud] 安装已中止，设备未做任何修改。"; exit 1; }

echo ""
echo "=========================================="
echo "  蜂助手 S1 CPE 去云控改造 - 安装程序"
echo "=========================================="
echo ""

# ---------- 1. 环境检查 ----------
say "检查设备环境..."

if [ ! -d /usr/aos ]; then
    fail "未找到 /usr/aos 目录，这不是蜂助手 S1 设备？"
fi

if [ ! -f "$TARGET" ]; then
    fail "未找到 $TARGET，设备系统异常。"
fi

# 确认是原厂或已改造的设备（有原厂包备份）
if [ ! -f "$FACTORY" ]; then
    say "警告：未找到原厂包备份 $FACTORY"
    say "      仍可继续，但回退保障会依赖 $BACKUP"
fi

# 空间检查（需要约 1.3MB）
FREE=$(df -k /tmp 2>/dev/null | tail -1 | awk '{print $4}')
if [ -n "$FREE" ] && [ "$FREE" -lt 4096 ]; then
    fail "/tmp 空间不足（可用 ${FREE}KB，需要约 1300KB）。"
fi
say "  ✓ 环境检查通过"

# 显示当前版本
CUR_MD5=$(md5sum "$TARGET" 2>/dev/null | cut -d' ' -f1)
say "  当前包 md5: $CUR_MD5"
if [ "$CUR_MD5" = "$PKG_MD5" ]; then
    say ""
    say "  设备已经安装了这个版本，无需重复安装。"
    say "  如需重新安装，请手动执行安装步骤。"
    echo ""
    exit 0
fi

# ---------- 2. 下载 ----------
say ""
say "下载安装包（约 1.2MB）..."

# 优先用 curl（支持 https），回退到 wget
if command -v curl >/dev/null 2>&1; then
    curl -k -sL --connect-timeout 20 -m 180 -o "$TMP" "$PKG_URL"
    RC=$?
elif command -v wget >/dev/null 2>&1; then
    wget -q --no-check-certificate -O "$TMP" "$PKG_URL" 2>/dev/null
    RC=$?
else
    fail "设备上没有 curl 也没有 wget，无法下载。请手动安装。"
fi

if [ $RC -ne 0 ] || [ ! -f "$TMP" ]; then
    fail "下载失败（网络问题？）。请检查设备能否上网，或改用手动安装。"
fi

# ---------- 3. 校验 ----------
say "校验完整性..."

GOT_MD5=$(md5sum "$TMP" 2>/dev/null | cut -d' ' -f1)
GOT_SIZE=$(wc -c < "$TMP" 2>/dev/null | tr -d ' ')
if [ "$GOT_MD5" != "$PKG_MD5" ]; then
    rm -f "$TMP"
    fail "md5 校验失败！
         期望: $PKG_MD5
         实际: $GOT_MD5
         文件可能损坏或下载不完整。请重试。"
fi
if [ -n "$GOT_SIZE" ] && [ "$GOT_SIZE" != "$PKG_SIZE" ]; then
    rm -f "$TMP"
    fail "文件大小不符（期望 $PKG_SIZE 字节，实际 $GOT_SIZE 字节）。
         下载可能被截断，请重试。"
fi
say "  ✓ md5 校验通过（$GOT_SIZE 字节）"

# 额外：验证是有效的 tar.gz
if ! tar -tzf "$TMP" >/dev/null 2>&1; then
    rm -f "$TMP"
    fail "下载的文件不是有效的压缩包。"
fi
say "  ✓ 压缩包结构有效"

# ---------- 4. 备份 + 安装 ----------
say ""
say "备份当前包 → $BACKUP"
cp "$TARGET" "$BACKUP" || fail "备份失败，磁盘空间不足？"

# 验证备份
BK_MD5=$(md5sum "$BACKUP" 2>/dev/null | cut -d' ' -f1)
if [ "$BK_MD5" != "$CUR_MD5" ]; then
    fail "备份校验失败，为安全起见中止。"
fi
say "  ✓ 备份完成（md5: $BK_MD5）"

say "安装新包 → $TARGET"
cp "$TMP" "$TARGET" || fail "写入失败。"

# 验证安装结果
NEW_MD5=$(md5sum "$TARGET" 2>/dev/null | cut -d' ' -f1)
if [ "$NEW_MD5" != "$PKG_MD5" ]; then
    say "  写入校验失败，正在回滚..."
    cp "$BACKUP" "$TARGET"
    fail "写入校验失败，已回滚到原包。"
fi
say "  ✓ 安装成功（md5: $NEW_MD5）"

sync
rm -f "$TMP"

# ---------- 5. 完成 ----------
echo ""
echo "=========================================="
echo "  ✓ 安装完成！"
echo "=========================================="
echo ""
echo "  即将重启设备（约 1 分钟）..."
echo ""
echo "  重启后请访问工具箱："
echo "    http://192.168.1.1:8088"
echo ""
echo "  功能：IMEI 改串 / 锁频段 / 锁定频点·小区 / 网口与上网优先级 / 管理后台密码 / 数据面板"
echo ""
echo "  如需恢复原厂："
echo "    cp $FACTORY $TARGET && reboot"
echo ""
echo "  5 秒后重启，按 Ctrl+C 可取消..."
echo ""

sleep 5
sync
reboot
