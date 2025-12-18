#set page(
  margin: (top: 2.54cm, bottom: 2.54cm, left: 3.17cm, right: 3.17cm), 
  footer: context [
    #set align(center)
    #counter(page).display()
  ]
)
#set text(font: ("Times New Roman", "Source Han Serif SC"), size: 12pt)
#set par(first-line-indent: (amount: 2em, all: true))

// 缩进函数：输入缩进距离（em），返回带缩进的块
#let indent-block(amount, content) = {
  block(inset: (left: amount))[
    #content
  ]
}

// 设置标题样式
#set heading(numbering: (..nums) => {
  let level = nums.pos().len()
  if level == 1 {
    // 一级标题：1, 2, 3...
    numbering("1 ", ..nums)
  } else if level == 2 {
    // 二级标题：1.1, 1.2, 1.3...
    let parent = nums.pos().first()
    let current = nums.pos().last()
    numbering("1.", parent)
    numbering("1 ", current)
  }
})

// 设置标题字体大小和粗体
#show heading.where(level: 1): it => {
  set text(size: 18pt, weight: "bold")
  it
  v(1em)
}

#show heading.where(level: 2): it => {
  set text(size: 16pt, weight: "bold")
  it
  v(1em)
}

#set enum(numbering: "(i)")

// 设置代码块样式：带背景框、边框和行号
#show raw.where(block: true): it => {
  block(
    width: 100%,
    fill: luma(245),
    inset: 10pt,
    radius: 4pt,
    stroke: (paint: luma(220), thickness: 1pt),
  )[
    #set par(justify: false)
    #set text(size: 8pt)
    #it
  ]
}

// 为代码块添加行号（只在多行代码块中显示）
#show raw.line: it => {
  // 只有当代码块有多行时才显示行号
  if it.count > 1 {
    box(width: 2em, {
      text(fill: luma(120), str(it.number))
      h(0.5em)
    })
    it.body
  } else {
    // 单行代码或行内代码不显示行号
    it.body
  }
}

// 设置行内代码样式：带浅色背景
#show raw.where(block: false): box.with(
  fill: luma(245),
  inset: (x: 3pt, y: 0pt),
  outset: (y: 3pt),
  radius: 2pt,
)

#align(center)[
  #text(size: 20pt)[第4章实验 - 优化Y86-64流水线处理器性能]
  
  #text(size: 14pt)[1120231863 #h(1em) 左逸龙]
  
  #text(size: 14pt)[#datetime.today().display("[month repr:long], [day] [year]")]
]

#v(3em)
