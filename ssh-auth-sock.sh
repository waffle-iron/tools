
# ソケットリンク
SSH_SOCK_SYMLINK=~/.ssh-auth-sock

# ログイン時の処理
ssh_auth_sock_login() {
    # SSH_AUTH_SOCK が無効(≒エージェント認証が有効でない)
    [ -z "$SSH_AUTH_SOCK" ] && return 0

    # 認証ソケットが既にソケットリンクに向けられている
    [ $SSH_SOCK_SYMLINK = "$SSH_AUTH_SOCK" ] && return 0

    # ソケットリンクが無効でSSH_AUTH_SOCKが有効なら
    # ソケットリンクを新しく張る
    if [ ! -S $SSH_SOCK_SYMLINK -a -S "$SSH_AUTH_SOCK" ]; then
        rm -f $SSH_SOCK_SYMLINK
        ln -s $SSH_AUTH_SOCK $SSH_SOCK_SYMLINK
        SSH_AUTH_SOCK_ORG=$SSH_AUTH_SOCK
    fi

    export SSH_AUTH_SOCK=$SSH_SOCK_SYMLINK
}

# ログアウト時の処理
ssh_auth_sock_logout() {

    # SSH_AUTH_SOCK が無効(≒エージェント認証が有効でない)
    [ -z "$SSH_AUTH_SOCK" ] && return 0

    # ソケットリンクを使用していない
    [ ! -S $SSH_SOCK_SYMLINK ] && return 0

    # ソケットリンクの指す先が、このシェルへのログインで作られたソケットでない
    [ `readlink $SSH_AUTH_SYMLNK` != "$SSH_AUTH_SOCK_ORG" ] && return 0

    # ほかに有効なSSH認証ソケットが残っていないか探す
    local foundsock
    for f in `\ls -1 /tmp/ssh-*/agent.*`; do
        if [ -S $f -a $f != "$SSH_AUTH_SOCK_ORG" ]; then
            foundsock=$f
            break
        fi
    done

    # 有効なソケットにリンクを張りなおす。なければリンクは消す
    rm $SSH_SOCK_SYMLINK
    [ -n "$foundsock" ] && ln -s $foundsock $SSH_SOCK_SYMLINK
}
