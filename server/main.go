package main

import (
	"github.com/gogf/gf/v2/frame/g"
)

func main() {
	s := g.Server()

	// 设置静态文件目录
	// 将 public 目录下的文件作为静态资源提供服务
	s.SetIndexFolder(true)
	s.AddStaticPath("/ai/deepseek", "/home/ai/deepseek/")

	// 启动服务器，监听 8080 端口
	s.SetPort(9090)
	s.Run()
}
