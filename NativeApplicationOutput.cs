using System;
using System.Globalization;
using System.Text;

/// <summary>
/// Represents output from a native application invocation.
/// Wraps a string value with an <see cref="IsError"/> property that indicates
/// whether the line originated from STDERR.
/// All <see cref="string"/> instance members are delegated to the inner value,
/// so this type can be used as a drop-in replacement for <see cref="string"/>
/// while preserving the error metadata.
/// </summary>
public class NativeApplicationOutput : IComparable, IComparable<string>, IEquatable<string>
{
    private readonly string _value;

    /// <summary>
    /// Gets a value indicating whether this output line originated from STDERR.
    /// </summary>
    public bool IsError { get; private set; }

    /// <summary>
    /// Gets the number of characters in the output line.
    /// </summary>
    public int Length { get { return _value.Length; } }

    /// <summary>
    /// Gets the character at the specified index.
    /// </summary>
    /// <param name="index">The zero-based index of the character.</param>
    /// <returns>The character at position <paramref name="index"/>.</returns>
    public char this[int index] { get { return _value[index]; } }

    /// <summary>
    /// Initializes a new instance of <see cref="NativeApplicationOutput"/>.
    /// </summary>
    /// <param name="value">The string content of the output line.</param>
    /// <param name="isError">
    /// <c>true</c> if the line originated from STDERR; otherwise, <c>false</c>.
    /// </param>
    public NativeApplicationOutput(string value, bool isError)
    {
        _value = value ?? string.Empty;
        IsError = isError;
    }

    /// <summary>
    /// Implicitly converts a <see cref="NativeApplicationOutput"/> to a <see cref="string"/>.
    /// </summary>
    /// <param name="output">The output to convert.</param>
    /// <returns>The underlying string value, or <c>null</c> if <paramref name="output"/> is <c>null</c>.</returns>
    public static implicit operator string(NativeApplicationOutput output)
    {
        return output == null ? null : output._value;
    }

    /// <inheritdoc/>
    public override string ToString() { return _value; }

    /// <summary>
    /// Returns the string value using the specified format provider.
    /// </summary>
    /// <param name="provider">An object that supplies culture-specific formatting information.</param>
    /// <returns>The string value.</returns>
    public string ToString(IFormatProvider provider) { return _value.ToString(provider); }

    /// <inheritdoc/>
    public override int GetHashCode() { return _value.GetHashCode(); }

    /// <inheritdoc/>
    public override bool Equals(object obj)
    {
        var other = obj as NativeApplicationOutput;
        if (other != null) return _value.Equals(other._value);
        var s = obj as string;
        if (s != null) return _value.Equals(s);
        return false;
    }

    /// <inheritdoc/>
    public int CompareTo(object value)
    {
        var other = value as NativeApplicationOutput;
        if (other != null) return _value.CompareTo(other._value);
        return _value.CompareTo(value);
    }

    /// <inheritdoc/>
    public int CompareTo(string strB) { return _value.CompareTo(strB); }

    /// <inheritdoc/>
    public bool Equals(string value) { return _value.Equals(value); }

    /// <summary>
    /// Determines whether this instance and a specified string have the same value,
    /// using the specified comparison rules.
    /// </summary>
    /// <param name="value">The string to compare to.</param>
    /// <param name="comparisonType">The comparison rules to use.</param>
    /// <returns><c>true</c> if the values are equal; otherwise, <c>false</c>.</returns>
    public bool Equals(string value, StringComparison comparisonType) { return _value.Equals(value, comparisonType); }

    /// <summary>Returns a copy of this string object.</summary>
    public object Clone() { return _value.Clone(); }

    /// <summary>
    /// Returns a value indicating whether a specified substring occurs within this string.
    /// </summary>
    /// <param name="value">The string to seek.</param>
    /// <returns><c>true</c> if <paramref name="value"/> occurs within this string; otherwise, <c>false</c>.</returns>
    public bool Contains(string value) { return _value.Contains(value); }

    /// <summary>
    /// Copies a specified number of characters to a character array.
    /// </summary>
    /// <param name="sourceIndex">The starting position in this instance.</param>
    /// <param name="destination">The destination character array.</param>
    /// <param name="destinationIndex">The starting position in <paramref name="destination"/>.</param>
    /// <param name="count">The number of characters to copy.</param>
    public void CopyTo(int sourceIndex, char[] destination, int destinationIndex, int count)
    {
        _value.CopyTo(sourceIndex, destination, destinationIndex, count);
    }

    /// <summary>Determines whether the end of this string matches the specified string.</summary>
    /// <param name="value">The string to compare.</param>
    /// <returns><c>true</c> if <paramref name="value"/> matches the end of this string; otherwise, <c>false</c>.</returns>
    public bool EndsWith(string value) { return _value.EndsWith(value); }

    /// <inheritdoc cref="EndsWith(string)"/>
    /// <param name="value">The string to compare.</param>
    /// <param name="comparisonType">The comparison rules to use.</param>
    public bool EndsWith(string value, StringComparison comparisonType) { return _value.EndsWith(value, comparisonType); }

    /// <inheritdoc cref="EndsWith(string)"/>
    /// <param name="value">The string to compare.</param>
    /// <param name="ignoreCase">Whether to ignore case during comparison.</param>
    /// <param name="culture">Cultural information for comparison.</param>
    public bool EndsWith(string value, bool ignoreCase, CultureInfo culture) { return _value.EndsWith(value, ignoreCase, culture); }

    /// <summary>Reports the zero-based index of the first occurrence of a character.</summary>
    /// <param name="value">The character to seek.</param>
    /// <returns>The index position, or -1 if not found.</returns>
    public int IndexOf(char value) { return _value.IndexOf(value); }

    /// <inheritdoc cref="IndexOf(char)"/>
    /// <param name="value">The character to seek.</param>
    /// <param name="startIndex">The search starting position.</param>
    public int IndexOf(char value, int startIndex) { return _value.IndexOf(value, startIndex); }

    /// <inheritdoc cref="IndexOf(char)"/>
    /// <param name="value">The character to seek.</param>
    /// <param name="startIndex">The search starting position.</param>
    /// <param name="count">The number of character positions to examine.</param>
    public int IndexOf(char value, int startIndex, int count) { return _value.IndexOf(value, startIndex, count); }

    /// <summary>Reports the zero-based index of the first occurrence of a string.</summary>
    /// <param name="value">The string to seek.</param>
    /// <returns>The index position, or -1 if not found.</returns>
    public int IndexOf(string value) { return _value.IndexOf(value); }

    /// <inheritdoc cref="IndexOf(string)"/>
    /// <param name="value">The string to seek.</param>
    /// <param name="startIndex">The search starting position.</param>
    public int IndexOf(string value, int startIndex) { return _value.IndexOf(value, startIndex); }

    /// <inheritdoc cref="IndexOf(string)"/>
    /// <param name="value">The string to seek.</param>
    /// <param name="startIndex">The search starting position.</param>
    /// <param name="count">The number of character positions to examine.</param>
    public int IndexOf(string value, int startIndex, int count) { return _value.IndexOf(value, startIndex, count); }

    /// <inheritdoc cref="IndexOf(string)"/>
    /// <param name="value">The string to seek.</param>
    /// <param name="comparisonType">The comparison rules to use.</param>
    public int IndexOf(string value, StringComparison comparisonType) { return _value.IndexOf(value, comparisonType); }

    /// <inheritdoc cref="IndexOf(string)"/>
    /// <param name="value">The string to seek.</param>
    /// <param name="startIndex">The search starting position.</param>
    /// <param name="comparisonType">The comparison rules to use.</param>
    public int IndexOf(string value, int startIndex, StringComparison comparisonType) { return _value.IndexOf(value, startIndex, comparisonType); }

    /// <inheritdoc cref="IndexOf(string)"/>
    /// <param name="value">The string to seek.</param>
    /// <param name="startIndex">The search starting position.</param>
    /// <param name="count">The number of character positions to examine.</param>
    /// <param name="comparisonType">The comparison rules to use.</param>
    public int IndexOf(string value, int startIndex, int count, StringComparison comparisonType) { return _value.IndexOf(value, startIndex, count, comparisonType); }

    /// <summary>Reports the zero-based index of the first occurrence of any character in a specified array.</summary>
    /// <param name="anyOf">The characters to seek.</param>
    /// <returns>The index position, or -1 if not found.</returns>
    public int IndexOfAny(char[] anyOf) { return _value.IndexOfAny(anyOf); }

    /// <inheritdoc cref="IndexOfAny(char[])"/>
    /// <param name="anyOf">The characters to seek.</param>
    /// <param name="startIndex">The search starting position.</param>
    public int IndexOfAny(char[] anyOf, int startIndex) { return _value.IndexOfAny(anyOf, startIndex); }

    /// <inheritdoc cref="IndexOfAny(char[])"/>
    /// <param name="anyOf">The characters to seek.</param>
    /// <param name="startIndex">The search starting position.</param>
    /// <param name="count">The number of character positions to examine.</param>
    public int IndexOfAny(char[] anyOf, int startIndex, int count) { return _value.IndexOfAny(anyOf, startIndex, count); }

    /// <summary>Returns a new string in which a specified string is inserted at a specified index.</summary>
    /// <param name="startIndex">The position of the insertion.</param>
    /// <param name="value">The string to insert.</param>
    /// <returns>A new string with <paramref name="value"/> inserted.</returns>
    public string Insert(int startIndex, string value) { return _value.Insert(startIndex, value); }

    /// <summary>Indicates whether this string is in Unicode normalization form C.</summary>
    /// <returns><c>true</c> if this string is normalized; otherwise, <c>false</c>.</returns>
    public bool IsNormalized() { return _value.IsNormalized(); }

    /// <summary>Indicates whether this string is in the specified Unicode normalization form.</summary>
    /// <param name="normalizationForm">The normalization form to check.</param>
    /// <returns><c>true</c> if this string is normalized; otherwise, <c>false</c>.</returns>
    public bool IsNormalized(NormalizationForm normalizationForm) { return _value.IsNormalized(normalizationForm); }

    /// <summary>Reports the zero-based index of the last occurrence of a character.</summary>
    /// <param name="value">The character to seek.</param>
    /// <returns>The index position, or -1 if not found.</returns>
    public int LastIndexOf(char value) { return _value.LastIndexOf(value); }

    /// <inheritdoc cref="LastIndexOf(char)"/>
    /// <param name="value">The character to seek.</param>
    /// <param name="startIndex">The search starting position (searching backward).</param>
    public int LastIndexOf(char value, int startIndex) { return _value.LastIndexOf(value, startIndex); }

    /// <inheritdoc cref="LastIndexOf(char)"/>
    /// <param name="value">The character to seek.</param>
    /// <param name="startIndex">The search starting position (searching backward).</param>
    /// <param name="count">The number of character positions to examine.</param>
    public int LastIndexOf(char value, int startIndex, int count) { return _value.LastIndexOf(value, startIndex, count); }

    /// <summary>Reports the zero-based index of the last occurrence of a string.</summary>
    /// <param name="value">The string to seek.</param>
    /// <returns>The index position, or -1 if not found.</returns>
    public int LastIndexOf(string value) { return _value.LastIndexOf(value); }

    /// <inheritdoc cref="LastIndexOf(string)"/>
    /// <param name="value">The string to seek.</param>
    /// <param name="startIndex">The search starting position (searching backward).</param>
    public int LastIndexOf(string value, int startIndex) { return _value.LastIndexOf(value, startIndex); }

    /// <inheritdoc cref="LastIndexOf(string)"/>
    /// <param name="value">The string to seek.</param>
    /// <param name="startIndex">The search starting position (searching backward).</param>
    /// <param name="count">The number of character positions to examine.</param>
    public int LastIndexOf(string value, int startIndex, int count) { return _value.LastIndexOf(value, startIndex, count); }

    /// <inheritdoc cref="LastIndexOf(string)"/>
    /// <param name="value">The string to seek.</param>
    /// <param name="comparisonType">The comparison rules to use.</param>
    public int LastIndexOf(string value, StringComparison comparisonType) { return _value.LastIndexOf(value, comparisonType); }

    /// <inheritdoc cref="LastIndexOf(string)"/>
    /// <param name="value">The string to seek.</param>
    /// <param name="startIndex">The search starting position (searching backward).</param>
    /// <param name="comparisonType">The comparison rules to use.</param>
    public int LastIndexOf(string value, int startIndex, StringComparison comparisonType) { return _value.LastIndexOf(value, startIndex, comparisonType); }

    /// <inheritdoc cref="LastIndexOf(string)"/>
    /// <param name="value">The string to seek.</param>
    /// <param name="startIndex">The search starting position (searching backward).</param>
    /// <param name="count">The number of character positions to examine.</param>
    /// <param name="comparisonType">The comparison rules to use.</param>
    public int LastIndexOf(string value, int startIndex, int count, StringComparison comparisonType) { return _value.LastIndexOf(value, startIndex, count, comparisonType); }

    /// <summary>Reports the zero-based index of the last occurrence of any character in a specified array.</summary>
    /// <param name="anyOf">The characters to seek.</param>
    /// <returns>The index position, or -1 if not found.</returns>
    public int LastIndexOfAny(char[] anyOf) { return _value.LastIndexOfAny(anyOf); }

    /// <inheritdoc cref="LastIndexOfAny(char[])"/>
    /// <param name="anyOf">The characters to seek.</param>
    /// <param name="startIndex">The search starting position (searching backward).</param>
    public int LastIndexOfAny(char[] anyOf, int startIndex) { return _value.LastIndexOfAny(anyOf, startIndex); }

    /// <inheritdoc cref="LastIndexOfAny(char[])"/>
    /// <param name="anyOf">The characters to seek.</param>
    /// <param name="startIndex">The search starting position (searching backward).</param>
    /// <param name="count">The number of character positions to examine.</param>
    public int LastIndexOfAny(char[] anyOf, int startIndex, int count) { return _value.LastIndexOfAny(anyOf, startIndex, count); }

    /// <summary>Returns the string in Unicode normalization form C.</summary>
    /// <returns>A normalized copy of this string.</returns>
    public string Normalize() { return _value.Normalize(); }

    /// <summary>Returns the string in the specified Unicode normalization form.</summary>
    /// <param name="normalizationForm">The normalization form to use.</param>
    /// <returns>A normalized copy of this string.</returns>
    public string Normalize(NormalizationForm normalizationForm) { return _value.Normalize(normalizationForm); }

    /// <summary>Returns a new string right-aligned and padded on the left with spaces to a specified total length.</summary>
    /// <param name="totalWidth">The total number of characters in the resulting string.</param>
    /// <returns>The padded string.</returns>
    public string PadLeft(int totalWidth) { return _value.PadLeft(totalWidth); }

    /// <inheritdoc cref="PadLeft(int)"/>
    /// <param name="totalWidth">The total number of characters in the resulting string.</param>
    /// <param name="paddingChar">The padding character.</param>
    public string PadLeft(int totalWidth, char paddingChar) { return _value.PadLeft(totalWidth, paddingChar); }

    /// <summary>Returns a new string left-aligned and padded on the right with spaces to a specified total length.</summary>
    /// <param name="totalWidth">The total number of characters in the resulting string.</param>
    /// <returns>The padded string.</returns>
    public string PadRight(int totalWidth) { return _value.PadRight(totalWidth); }

    /// <inheritdoc cref="PadRight(int)"/>
    /// <param name="totalWidth">The total number of characters in the resulting string.</param>
    /// <param name="paddingChar">The padding character.</param>
    public string PadRight(int totalWidth, char paddingChar) { return _value.PadRight(totalWidth, paddingChar); }

    /// <summary>Returns a new string with characters removed from the specified position to the end.</summary>
    /// <param name="startIndex">The position to begin deleting characters.</param>
    /// <returns>A new string without the removed characters.</returns>
    public string Remove(int startIndex) { return _value.Remove(startIndex); }

    /// <summary>Returns a new string with a specified number of characters removed from a specified position.</summary>
    /// <param name="startIndex">The position to begin deleting characters.</param>
    /// <param name="count">The number of characters to delete.</param>
    /// <returns>A new string without the removed characters.</returns>
    public string Remove(int startIndex, int count) { return _value.Remove(startIndex, count); }

    /// <summary>Returns a new string in which all occurrences of a character are replaced.</summary>
    /// <param name="oldChar">The character to be replaced.</param>
    /// <param name="newChar">The character to replace all occurrences of <paramref name="oldChar"/>.</param>
    /// <returns>A new string with the replacements.</returns>
    public string Replace(char oldChar, char newChar) { return _value.Replace(oldChar, newChar); }

    /// <summary>Returns a new string in which all occurrences of a string are replaced.</summary>
    /// <param name="oldValue">The string to be replaced.</param>
    /// <param name="newValue">The string to replace all occurrences of <paramref name="oldValue"/>.</param>
    /// <returns>A new string with the replacements.</returns>
    public string Replace(string oldValue, string newValue) { return _value.Replace(oldValue, newValue); }

    /// <summary>Splits the string into substrings delimited by the specified characters.</summary>
    /// <param name="separator">The delimiting characters.</param>
    /// <returns>An array of substrings.</returns>
    public string[] Split(params char[] separator) { return _value.Split(separator); }

    /// <inheritdoc cref="Split(char[])"/>
    /// <param name="separator">The delimiting characters.</param>
    /// <param name="count">The maximum number of substrings to return.</param>
    public string[] Split(char[] separator, int count) { return _value.Split(separator, count); }

    /// <inheritdoc cref="Split(char[])"/>
    /// <param name="separator">The delimiting characters.</param>
    /// <param name="options">Options for removing empty entries.</param>
    public string[] Split(char[] separator, StringSplitOptions options) { return _value.Split(separator, options); }

    /// <inheritdoc cref="Split(char[])"/>
    /// <param name="separator">The delimiting characters.</param>
    /// <param name="count">The maximum number of substrings to return.</param>
    /// <param name="options">Options for removing empty entries.</param>
    public string[] Split(char[] separator, int count, StringSplitOptions options) { return _value.Split(separator, count, options); }

    /// <summary>Splits the string into substrings delimited by the specified strings.</summary>
    /// <param name="separator">The delimiting strings.</param>
    /// <param name="options">Options for removing empty entries.</param>
    /// <returns>An array of substrings.</returns>
    public string[] Split(string[] separator, StringSplitOptions options) { return _value.Split(separator, options); }

    /// <inheritdoc cref="Split(string[], StringSplitOptions)"/>
    /// <param name="separator">The delimiting strings.</param>
    /// <param name="count">The maximum number of substrings to return.</param>
    /// <param name="options">Options for removing empty entries.</param>
    public string[] Split(string[] separator, int count, StringSplitOptions options) { return _value.Split(separator, count, options); }

    /// <summary>Determines whether the beginning of this string matches the specified string.</summary>
    /// <param name="value">The string to compare.</param>
    /// <returns><c>true</c> if <paramref name="value"/> matches the beginning of this string; otherwise, <c>false</c>.</returns>
    public bool StartsWith(string value) { return _value.StartsWith(value); }

    /// <inheritdoc cref="StartsWith(string)"/>
    /// <param name="value">The string to compare.</param>
    /// <param name="comparisonType">The comparison rules to use.</param>
    public bool StartsWith(string value, StringComparison comparisonType) { return _value.StartsWith(value, comparisonType); }

    /// <inheritdoc cref="StartsWith(string)"/>
    /// <param name="value">The string to compare.</param>
    /// <param name="ignoreCase">Whether to ignore case during comparison.</param>
    /// <param name="culture">Cultural information for comparison.</param>
    public bool StartsWith(string value, bool ignoreCase, CultureInfo culture) { return _value.StartsWith(value, ignoreCase, culture); }

    /// <summary>Retrieves a substring starting at the specified position.</summary>
    /// <param name="startIndex">The zero-based starting position.</param>
    /// <returns>The substring.</returns>
    public string Substring(int startIndex) { return _value.Substring(startIndex); }

    /// <summary>Retrieves a substring of the specified length starting at the specified position.</summary>
    /// <param name="startIndex">The zero-based starting position.</param>
    /// <param name="length">The number of characters in the substring.</param>
    /// <returns>The substring.</returns>
    public string Substring(int startIndex, int length) { return _value.Substring(startIndex, length); }

    /// <summary>Copies the characters to a new character array.</summary>
    /// <returns>A character array containing the characters of this string.</returns>
    public char[] ToCharArray() { return _value.ToCharArray(); }

    /// <summary>Copies a range of characters to a new character array.</summary>
    /// <param name="startIndex">The starting position.</param>
    /// <param name="length">The number of characters to copy.</param>
    /// <returns>A character array containing the specified characters.</returns>
    public char[] ToCharArray(int startIndex, int length) { return _value.ToCharArray(startIndex, length); }

    /// <summary>Returns a copy of this string converted to lowercase.</summary>
    /// <returns>The lowercase equivalent.</returns>
    public string ToLower() { return _value.ToLower(); }

    /// <inheritdoc cref="ToLower()"/>
    /// <param name="culture">The culture rules for casing.</param>
    public string ToLower(CultureInfo culture) { return _value.ToLower(culture); }

    /// <summary>Returns a copy of this string converted to lowercase using the invariant culture.</summary>
    /// <returns>The lowercase equivalent.</returns>
    public string ToLowerInvariant() { return _value.ToLowerInvariant(); }

    /// <summary>Returns a copy of this string converted to uppercase.</summary>
    /// <returns>The uppercase equivalent.</returns>
    public string ToUpper() { return _value.ToUpper(); }

    /// <inheritdoc cref="ToUpper()"/>
    /// <param name="culture">The culture rules for casing.</param>
    public string ToUpper(CultureInfo culture) { return _value.ToUpper(culture); }

    /// <summary>Returns a copy of this string converted to uppercase using the invariant culture.</summary>
    /// <returns>The uppercase equivalent.</returns>
    public string ToUpperInvariant() { return _value.ToUpperInvariant(); }

    /// <summary>Removes all leading and trailing white-space characters.</summary>
    /// <returns>The trimmed string.</returns>
    public string Trim() { return _value.Trim(); }

    /// <summary>Removes all leading and trailing occurrences of the specified characters.</summary>
    /// <param name="trimChars">The characters to remove.</param>
    /// <returns>The trimmed string.</returns>
    public string Trim(params char[] trimChars) { return _value.Trim(trimChars); }

    /// <summary>Removes all trailing occurrences of the specified characters.</summary>
    /// <param name="trimChars">The characters to remove.</param>
    /// <returns>The trimmed string.</returns>
    public string TrimEnd(params char[] trimChars) { return _value.TrimEnd(trimChars); }

    /// <summary>Removes all leading occurrences of the specified characters.</summary>
    /// <param name="trimChars">The characters to remove.</param>
    /// <returns>The trimmed string.</returns>
    public string TrimStart(params char[] trimChars) { return _value.TrimStart(trimChars); }
}
