/*
 * Hexo filter: 将文章中的本地图片路径转换为 MinIO/CDN 前缀 URL（可选）
 * 生效条件：存在环境变量 MINIO_PUBLIC_PREFIX，例如 https://cdn.example.com/blog
 * 仅处理 Markdown 图片语法 ![alt](path) 且 path 以 /images 或 images/ 开头
 */

const cdn = process.env.MINIO_PUBLIC_PREFIX;
if (cdn) {
  hexo.extend.filter.register('after_post_render', function (data) {
    // 替换 markdown 渲染后的 HTML 中 <img src="...">
    data.content = data.content.replace(/<img\s+[^>]*src=["']([^"']+)["']/g, (m, src) => {
      if (/^(https?:)?\/\//.test(src)) return m; // 已是绝对地址跳过
      if (/^(\/)?images\//.test(src)) {
        const norm = src.replace(/^\//, '');
        return m.replace(src, `${cdn.replace(/\/$/, '')}/${norm}`);
      }
      return m;
    });
    return data;
  });
}
