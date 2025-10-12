interface SearchHighlightProps {
  text: string
  searchTerm: string
}

export default function SearchHighlight({ text, searchTerm }: SearchHighlightProps) {
  if (!searchTerm.trim()) {
    return <>{text}</>
  }

  const parts = text.split(new RegExp(`(${searchTerm})`, "gi"))

  return (
    <>
      {parts.map((part, i) =>
        part.toLowerCase() === searchTerm.toLowerCase() ? (
          <span
            key={i}
            className="bg-purple-100 dark:bg-purple-900/30 text-purple-800 dark:text-purple-300 px-1 rounded"
          >
            {part}
          </span>
        ) : (
          <span key={i}>{part}</span>
        ),
      )}
    </>
  )
}
